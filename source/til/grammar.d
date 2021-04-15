module til.grammar;

import pegged.grammar;


mixin(grammar(`
    Til:
        Program           <- SubProgram endOfInput

        SubProgram        <- blank* Line (eol blank* Line)* blank*
        Line              <- Comment / Pipeline
        Comment           <~ "#" (!eol .)*

        Pipeline          <- Command (" | " Command)*
        Command           <- Name (" "+ Argument)*
        Argument          <- ExecList / SubList / SimpleList / String / SafeAtom
        SafeAtom          <- Float / Integer / Boolean / Name

        List              <- ListItem (" "+ ListItem)*
        ListItem          <- ExecList / SubList / SimpleList / String / Atom
        SimpleList        <- "(" List? ")"
        ExecList          <- "[" SubProgram "]"
        SubList           <- "{" SubProgram "}"

        String            <- SimpleString / SubstString
        SimpleString      <- ["] NotSubstitution ["]
        SubstString       <- ["] (Substitution / NotSubstitution)* ["]
        Substitution      <~ "$" Name
        NotSubstitution   <~ (!doublequote !"$" .)*

        Atom              <- Float / Integer / Boolean / Operator / Name
        Name              <~ "$"? [A-Za-z] [A-Za-z0-9_.]* "?"?

        Float             <~ [0-9]+ "." [0-9]+
        Integer           <~ [0-9]+
        Boolean           <- BooleanTrue / BooleanFalse
        BooleanTrue       <~ "true" / "yes"
        BooleanFalse      <~ "false" / "no"
        Operator          <~ "||" / "&&" / "<=" / ">=" / [&|+\-*/<>]
    `));
