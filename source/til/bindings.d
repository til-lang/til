import til.commands;
import til.grammar;
import til.nodes;
import til.process;

import std.string : toStringz;

Escopo[] scopes;


extern (C) size_t til_new_scope(char* description, size_t parent_index)
{
    Escopo parent = null;
    if (parent_index)
    {
        parent = scopes[parent_index];
    }
    auto escopo = new Escopo(parent, to!string(description));
    // XXX: it seems the module's static constructor is not being called.
    // TODO: figure out how to do it happen.
    escopo.commands = commands;
    scopes ~= escopo;
    return scopes.length - 1;
}

extern (C) int til_eval(size_t scope_index, char* description, char* code)
{
    auto escopo = scopes[scope_index];
    auto parser = new Parser(to!string(code));
    auto program = parser.run();
    auto process = new Process(to!string(description));
    auto context = process.run(program, escopo);
    return process.unixExitStatus(context);
}

Item[] getValueFromScope(size_t scope_index, char* name)
{
    auto escopo = scopes[scope_index];
    auto key = to!string(name);
    return escopo[key];
}

extern (C) char* til_get_string_value(size_t scope_index, char* name)
{
    return cast(char *)getValueFromScope(scope_index, name)[0]
        .toString()
        .toStringz;
}
extern (C) long til_get_integer_value(size_t scope_index, char* name)
{
    return getValueFromScope(scope_index, name)[0]
        .toInt();
}
extern (C) float til_get_float_value(size_t scope_index, char* name)
{
    return getValueFromScope(scope_index, name)[0]
        .toFloat();
}
extern (C) char til_get_bool_value(size_t scope_index, char* name)
{
    return getValueFromScope(scope_index, name)[0]
        .toBool();
}
