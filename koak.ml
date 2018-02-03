(* Main *)

open Llvm
open Llvm_target
open Llvm_scalar_opts

(* top ::= definition | external | expression | ';' *)
let rec main_loop optimizer stream =
    match Stream.peek stream with
    | None -> ()
    | Some (Token.Any ';') ->
        Stream.junk stream;
        main_loop optimizer stream
    | Some token ->
        begin
            try
                match token with
                | Token.Def ->
                    let e = Parser.parse_definition stream in
                    dump_value (Codegenerator.codegen_func optimizer e);
                | Token.Extern ->
                    let e = Parser.parse_extern stream in
                    dump_value (Codegenerator.codegen_proto e);
                | _ ->
                    let e = Parser.parse_topexpr stream in
                    dump_value (Codegenerator.codegen_func optimizer e);
            with
            | Stream.Error s ->
                Stream.junk stream;
                print_endline s;
        end;
        print_string "ready> "; flush stdout;
        main_loop optimizer stream

let _ =
    Hashtbl.add Parser.binop_precedence ':' 2;
    Hashtbl.add Parser.binop_precedence '<' 10;
    Hashtbl.add Parser.binop_precedence '+' 20;
    Hashtbl.add Parser.binop_precedence '-' 20;
    Hashtbl.add Parser.binop_precedence '*' 40;

    print_endline "KOAK, compiler/interpreter";
    print_string "ready> "; flush stdout;
    
    let stream = Lexer.lex (Stream.of_channel stdin) in
    let optimizer = PassManager.create_function Codegenerator.kmodule in
    begin
        add_instruction_combination optimizer;
        add_reassociation optimizer;
        add_gvn optimizer;
        add_cfg_simplification optimizer;
        ignore (PassManager.initialize optimizer);
    end;
    main_loop optimizer stream;

    dump_module Codegenerator.kmodule;
;;
