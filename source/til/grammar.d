module til.grammar;

import pegged.grammar;


ParseTree promote(ParseTree p)
{
    return p.children[0];
}

mixin(grammar(`
    Til:
        Program           <- SubProgram endOfInput

        SubProgram        <- blank* Line {promote} (eol blank* Line {promote})* blank*
        Line              <- Comment / Pipeline
        Comment           <~ "#" (!eol .)*

        Pipeline          <- Command (" | " Command)*
        Command           <- Name (" " Argument)*
        Argument          <- ExecList / SubList / SimpleList / String / SafeAtom
        SafeAtom          <- Float / UnitInteger / Integer / Boolean / Name

        List              <- ListItem (" " ListItem)*
        ListItem          <- ExecList / SubList / SimpleList / String / Atom
        SimpleList        <- "(" List? ")"
        ExecList          <- "[" SubProgram "]"
        SubList           <- "{" SubProgram "}"

        String            <- SimpleString / SubstString
        SimpleString      <- ["] NotSubstitution ["]
        SubstString       <- ["] (Substitution / NotSubstitution)* ["]
        Substitution      <~ "$" Name
        NotSubstitution   <~ (!doublequote !"$" .)*

        Atom              <- Float / UnitInteger / Integer / Boolean / Operator / Name
        Name              <~ [$>]? Identifier "?"?
        Identifier        <- [a-z] [a-z0-9_.]*

        Float             <~ [0-9]+ "." [0-9]+
        UnitInteger       <- Integer Unit
        Unit              <- "K" / "M" / "G" / "Ki" / "Mi" / "Gi"
        Integer           <~ [0-9]+
        Boolean           <- BooleanTrue / BooleanFalse
        BooleanTrue       <~ "true" / "yes"
        BooleanFalse      <~ "false" / "no"
        Operator          <~ "||" / "&&" / "<=" / ">=" / [&|+\-*/<>]
    `));
