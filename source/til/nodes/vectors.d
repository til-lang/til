module til.nodes.vectors;

import std.string : capitalize;

import til.nodes;



class Vector(T) : Item
{
    T[] values;

    auto type = ObjectType.Vector;
    string typeName = T.stringof ~ "_vector";

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
            long start = 0;
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
                start = startItem.toInt();
                if (start < 0)
                {
                    start = item.values.length + start;
                }
            }

            auto end = start + 1;
            if (context.size)
            {
                auto endItem = context.pop();
                if (endItem.toString() == "end")
                {
                    end = item.values.length;
                }
                else
                {
                    end = endItem.toInt();
                    if (end < 0)
                    {
                        end = item.values.length + end;
                    }
                }
            }

            context.exitCode = ExitCode.CommandSuccess;
            foreach (x; item.values[start..end].retro)
            {
                static if (__traits(isFloating, T))
                {
                    context.push(new FloatAtom(x));
                }
                else
                {
                    context.push(new IntegerAtom(x));
                }
            }
            return context;
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


class ByteVector : Vector!byte {}
class FloatVector : Vector!float {}
class IntVector : Vector!int {}
class LongVector : Vector!long {}
class DoubleVector : Vector!double {}
