module til.grammar;

import pegged.grammar;

debug
{
    import std.stdio;
}


ParseTree promote(ParseTree p)
{
    debug {stderr.writeln("Til:promoting ", p);}
    return p.children[0];
}

mixin(grammar(`
    Til:
        Program           <- SubProgram endOfInput

        SubProgram        <- blank* Line {promote} (eol blank* Line {promote})* blank*
        Line              <- Comment / Pipeline
        Comment           <~ "#" (!eol .)*

        Pipeline          <- Command (" | " Command)*
        Command           <- Name ((" " / eol blank* "." blank+) ListItem)*

        List              <- ListItem (" " ListItem)*
        ListItem          <- ExecList / SubList / Extraction / SimpleList / String / Atom
        SimpleList        <- "(" List? ")"
        Extraction        <- "<" List? ">"
        ExecList          <- "[" SubProgram "]"
        SubList           <- "{" SubProgram "}"

        String            <- SimpleString / SubstString
        SimpleString      <- ["] NotSubstitution ["]
        SubstString       <- ["] (Substitution / NotSubstitution)* ["]
        Substitution      <~ "$" Name
        NotSubstitution   <~ (!doublequote !"$" .)*

        Atom              <- Float / UnitInteger / Integer / Boolean / Name / Operator
        Name              <~ [$>]? Identifier "?"?
        Identifier        <- [a-z] [a-z0-9_.]*

        Float             <~ [0-9]+ "." [0-9]+
        UnitInteger       <- Integer Unit
        Unit              <- "K" / "M" / "G" / "Ki" / "Mi" / "Gi"
        Integer           <~ "-"? [0-9]+
        Boolean           <- BooleanTrue / BooleanFalse
        BooleanTrue       <~ "true" / "yes"
        BooleanFalse      <~ "false" / "no"
        Operator          <~ "||" / "&&" / "<=" / ">=" / "==" / [+\-*/<>]
    `));
