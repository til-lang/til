module til.nodes.program;

import std.array : join, split;
import std.uni : toUpper;

import til.nodes;
import til.packages;
import til.procedures;


class Program : Dict {
    string name;
    string full_name;
    string description;
    Dict globals;

    // CLI commands
    Command[string] subCommands;
    // General commands and procedures
    Command[string] procedures;

    this()
    {
        this.type = ObjectType.Program;
        this.commands = dictCommands;
        this.typeName = "program";
        this.globals = new Dict();
    }

    void initialize(CommandsMap commands, Dict environmentVariables)
    {
        debug {
            stderr.writeln("Initializing program");
        }
        this.commands = commands;

        debug {
            stderr.writeln("Adjusting configuration");
        }
        /*
        About [configuration]:
        - It must always follow the format "configuration/key";
        - No sub-keys are allowed;
        - No "direct" configuration is allowed.
        */
        Dict config = cast(Dict)(values["configuration"]);
        foreach (configSectionName, configSection; config.values)
        {
            auto d = cast(Dict)configSection;
            foreach (name, infoItem; d.values)
            {
                auto full_name = configSectionName ~ "." ~ name;

                auto info = cast(Dict)infoItem;
                Item* valuePtr = ("default" in info.values);
                if (valuePtr !is null)
                {
                    Item value = *valuePtr;

                    // port = 5000
                    globals[name] = value;
                    // http.port = 5000
                    globals[full_name] = value;
                }

                string envName = (configSectionName ~ "_" ~ name).toUpper;
                debug {
                    stderr.writeln("envName:", envName);
                }
                Item *envValuePtr = (envName in environmentVariables.values);
                if (envValuePtr !is null)
                {

                    String envValue = cast(String)(*envValuePtr);
                    debug {
                        stderr.writeln(" -->", envValue);
                    }
                    globals[name] = envValue;
                    globals[full_name] = envValue;
                    globals[envName] = envValue;
                }
            }
        }

        debug {
            stderr.writeln("Adjusting procedures");
        }

        // The program dict is loaded, now
        // act accordingly on each different section.
        Item *proceduresPtr = ("procedures" in values);
        if (proceduresPtr !is null)
        {
            Item procedures = *proceduresPtr;
            Dict proceduresDict = cast(Dict)procedures;
            foreach (name, infoItem; proceduresDict.values)
            {
                auto info = cast(Dict)infoItem;
                auto proc = new Procedure(
                    name,
                    cast(Dict)(info["parameters"]),
                    cast(SubProgram)(info["subprogram"])
                );
                this.procedures[name] = proc;
            }
        }

        debug {
            stderr.writeln("Adjusting commands");
        }

        Item *commandsPtr = ("commands" in values);
        if (commandsPtr !is null)
        {
            Item cmds = *commandsPtr;
            Dict commandsDict = cast(Dict)cmds;
            foreach (name, infoItem; commandsDict.values)
            {
                auto info = cast(Dict)infoItem;
                auto proc = new Procedure(
                    name,
                    cast(Dict)(info["parameters"]),
                    cast(SubProgram)(info["subprogram"])
                );
                subCommands[name] = proc;
            }
        }
    }

    // Conversions
    override string toString()
    {
        return "program " ~ name;
    }

    // Commands and procedures
    override Command getCommand(string name)
    {
        Command cmd;

        // If it's a procedure:
        auto cmdPtr = (name in this.procedures);
        if (cmdPtr !is null) return *cmdPtr;

        // If it's a built-in command:
        cmdPtr = (name in this.commands);
        if (cmdPtr !is null) return *cmdPtr;

        // If the command is present in an external package:
        bool success = {
            // exec -> exec
            if (importModule(this, name, name)) return true;

            // http.client.get -> http.client
            string packagePath = to!string(name.split(".")[0..$-1].join("."));
            if (this.importModule(packagePath)) return true;

            // http.client.get -> http
            packagePath = to!string(name.split(".")[0]);
            if (this.importModule(packagePath)) return true;

            return false;
        }();

        if (success) {
            // We imported the package, but we're not sure if this
            // name actually exists inside it:
            // (Important: do NOT call this method recursively!)
            cmdPtr = (name in this.procedures);
            if (cmdPtr !is null)
            {
                procedures[name] = *cmdPtr;
                cmd = *cmdPtr;
            }
        }
        else
        {
            debug {stderr.writeln("importModule failed");}
            debug {stderr.writeln("cmd:", cmd);}
        }

        // If such command doesn't seem to exist, `cmd` will be null:
        return cmd;
    }
}
