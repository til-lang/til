module til.nodes.vectors;

import std.string : capitalize;

import til.nodes;


CommandsMap byteVectorCommands;


class Vector(T) : Item
{
    T[] values;

    auto type = ObjectType.Vector;
    string typeName = T.stringof ~ "_vector";

    this(T[] values)
    {
        this();
        this.values = values;
        static if (T.stringof == "byte")
        {
            this.commands = byteVectorCommands;
        }
    }
    this()
    {
        this.commands["length"] = new Command(function(string path, Context context)
        {
            auto item = context.pop!(typeof(this))();
            context.push(item.values.length);
            return context;
        });

        this.commands["extract"] = new Command(function(string path, Context context)
        {
            auto item = context.pop!(typeof(this))();

            auto startItem = context.pop();
            size_t start = 0;
            if (startItem.toString() == "end")
            {
                start = item.values.length - 1;
                if (start < 0)
                {
                    start = 0;
                }
            }
            else
            {
                start = cast(size_t)(startItem.toInt());
                if (start < 0)
                {
                    start = item.values.length + start;
                }
            }

            if (context.size == 0)
            {
                return context.push(item.values[start]);
            }

            size_t end = start + 1;
            auto endItem = context.pop();
            if (endItem.toString() == "end")
            {
                end = item.values.length;
            }
            else
            {
                end = cast(size_t)(endItem.toInt());
                if (end < 0)
                {
                    end = item.values.length + end;
                }
            }

            context.exitCode = ExitCode.Success;
            Items items;
            foreach (x; item.values[start..end])
            {
                static if (__traits(isFloating, T))
                {
                    items ~= new FloatAtom(x);
                }
                else
                {
                    items ~= new IntegerAtom(x);
                }
            }
            return context.push(new SimpleList(items));
        });
    }
    override string toString()
    {
        return (
            this.typeName ~ ":"
            ~ to!string(
                this.values.map!(x => to!string(x)).join(" ")
            )
        );
    }
}


alias ByteVector = Vector!byte;
alias FloatVector = Vector!float;
alias IntVector = Vector!int;
alias LongVector = Vector!long;
alias DoubleVector = Vector!double;
