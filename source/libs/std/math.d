module til.std.math;

import std.conv;
import std.experimental.logger;

import til.escopo;
import til.nodes;


class Math : Escopo
{
    string name = "math";

    Result cmd_run(NamePath path, Args items)
    {
        int result = int_run(items);
        return new Atom(result);
    }

    int int_run(Args items)
    {
        /*
        set x [math.run 1 + 1]
        */
        trace(" MATH.RUN: ", items);

        ListItem lastItem;
        // For now, only integers are supported...
        int currentResult = false;
        void delegate(string, ListItem) currentHandler;
        int delegate(ListItem, ListItem)[string] operators;

        final void defaultHandler(string s, ListItem x)
        {
            trace("  defaultHandler ", s);
            trace( "saving item");
            lastItem = x;
            return;
        }
        currentHandler = &defaultHandler;

        /*
        The most usual way of implementing an operation handler
        is by returnin a CLOSURE whose "first argument" is
        the first value of an infix notation. For
        instance, `1 + 2` would first save `1`,
        then make a "sum-with-one" closure
        the currentHandler and then apply
        sum-with-one to `2`, resulting
        a `3`.
        */

        // -----------------------------------------------
        void operatorHandler(string operatorName, ListItem opItem)
        {
            ListItem t1 = lastItem;
            void operate(string strT2, ListItem t2)
            {
                auto newResult = {
                    switch(operatorName)
                    {
                        // -----------------------------------------------
                        // Operators implementations:
                        // TODO: use asInteger, asFloat and asString
                        // TODO: this could be entirely made at compile
                        // time, I assume...
                        case "+":
                            return to!int(t1.asString) + to!int(t2.asString);
                        case "-":
                            return to!int(t1.asString) - to!int(t2.asString);
                        case "*":
                            return to!int(t1.asString) * to!int(t2.asString);
                        case "/":
                            return to!int(t1.asString) / to!int(t2.asString);
                        default:
                            throw new Exception(
                                "Unknown operator: "
                                ~ operatorName
                            );
                    }
                }();
                trace(" newResult: ", to!string(newResult));

                lastItem = null;
                currentResult = newResult;
                currentHandler = &defaultHandler;
            }
            currentHandler = &operate;
        }

        // -----------------------------------------------
        void parentesisOpen()
        {
            // Consume the "(":
            items.popFront();

            auto newResult = int_run(items);
            currentResult = newResult;
        }

        // -----------------------------------------------
        // The loop:
        foreach(item; items)
        {
            string s = item.asString;
            trace("s: ", s, " ", to!string(item.type));

            if (item.type == ObjectTypes.Parentesis)
            {
                if (s == "(")
                {
                    parentesisOpen();
                    continue;
                }
                else if (s == ")")
                {
                    // Time to leave:
                    break;
                }
            }
            else if (item.type == ObjectTypes.Operator)
            {
                operatorHandler(s, item);
                continue;
            }
            // Not an operator? Must be a value...
            currentHandler(s, item);
        }
        trace("  returning ", to!string(currentResult));
        return currentResult;
    }

    override void loadCommands()
    {
        this.commands["run"] = &cmd_run;
    }
}
