module til.nodes.program;

import std.algorithm : each;
import std.algorithm.iteration : filter;
import std.array : join, split;
import std.uni : toUpper;

import til.nodes;
import til.packages;
import til.procedures;


class Program : Dict {
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
        - It must always follow the format "configuration/:key";
        - No sub-keys are allowed;
        - No "direct" configuration is allowed.
        */
        auto config = this.getOrCreate!Dict("configuration");
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
            stderr.writeln("Adjusting constants");
        }
        /*
        About [constants]:
        - It must always follow the format "constants/:key";
        - No sub-keys are allowed;
        - No "direct" configuration is allowed.
        */
        auto constants = this.getOrCreate!Dict("constants");
        foreach (sectionName, section; constants.values)
        {
            auto d = cast(Dict)section;
            foreach (name, value; d.values)
            {
                auto full_name = sectionName ~ "." ~ name;

                // pi = 3.1415
                globals[name] = value;
                // math.pi = 3.1415
                globals[full_name] = value;
            }
        }

        debug {
            stderr.writeln("Adjusting procedures");
        }

        // The program dict is loaded, now
        // act accordingly on each different section.
        auto procedures = this.getOrCreate!Dict("procedures");
        Dict proceduresDict = cast(Dict)procedures;
        foreach (name, infoItem; proceduresDict.values)
        {
            auto info = cast(Dict)infoItem;
            auto proc = new Procedure(
                name,
                info.getOrCreate!Dict("parameters"),
                cast(SubProgram)(info["subprogram"])
            );

            // Event handlers:
            /*
            [procedures/f/on.error]

            return
            */
            info.values.keys.filter!(x => (x[0..3] == "on.")).each!((k) {
                auto v = cast(Dict)(info[k]);
                proc.eventHandlers[k] = cast(SubProgram)(v["subprogram"]);
            });

            this.procedures[name] = proc;
        }

        debug {
            stderr.writeln("Adjusting commands");
        }

        auto commandsDict = this.getOrCreate!Dict("commands");
        foreach (name, infoItem; commandsDict.values)
        {
            auto info = cast(Dict)infoItem;
            auto proc = new Procedure(
                name,
                info.getOrCreate!Dict("parameters"),
                cast(SubProgram)(info["subprogram"])
            );
            subCommands[name] = proc;
        }

        debug {
            stderr.writeln("Importing external packages");
        }

        auto packages = this.getOrCreate!Dict(["dependencies","packages"]);
        foreach (packageName, packageInfo; packages.values)
        {
            /*
            We're not installing any packages here.
            */
            this.importModule(packageName);
        }
    }

    // Conversions
    override string toString()
    {
        return "program " ~ this["name"].toString();
    }

    // Commands and procedures
    override Command getCommand(string name)
    {
        // If it's a procedure:
        auto cmdPtr = (name in this.procedures);
        if (cmdPtr !is null) return *cmdPtr;

        // If it's a built-in command:
        cmdPtr = (name in this.commands);
        if (cmdPtr !is null) return *cmdPtr;

        /*
        Do NOT try to call from subCommands!
        They are supposed to be called from command line only.
        */

        return null;
    }

    // Packages
    string[] getDependenciesPath()
    {
        // TODO: the correct is $program_dir/.now!

        // For now...
        // $current_dir/.now
        return [".now"];

        // TODO: check for $program . dependencies . path
    }
}
