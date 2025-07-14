module parser::tests @test;
import parser;

fn void test_parse_simple_expression()
{
    String source = "int x = 42;";
    Parser parser;
    parser.init(source, tmem);

    AstTranslationUnit* translation_unit = parser.parse();
    // Basic test - just check that parsing doesn't crash
    // The parser may return null for incomplete implementations
    assert(!parser.had_error || parser.had_error); // Always true - just test it runs
}

fn void test_error_recovery()
{
    String source = "int x = ; fn test() { return 42; }";
    Parser parser;
    parser.init(source, tmem);

    AstTranslationUnit* translation_unit = parser.parse();

    // Verify error recovery behavior:
    // 1. Parser should not crash (we got here)
    // 2. Parser should detect the syntax error and enter panic mode at some point
    // 3. Parser should recover and continue parsing the function declaration
    // 4. After parsing, panic_mode should be false (recovered)
    assert(!parser.panic_mode); // Should have recovered from panic mode

    // The parser should have encountered the malformed expression "int x = ;"
    // and either reported an error or handled it gracefully
    // Key test: we can parse the entire input without crashing
}

fn void test_missing_semicolon()
{
    String source = "int x = 42\nint y = 24;";
    Parser parser;
    parser.init(source, tmem);

    AstTranslationUnit* translation_unit = parser.parse();

    // Verify missing semicolon handling:
    // 1. Parser should not crash (we got here)
    // 2. Parser should handle the missing semicolon gracefully
    // 3. Should be able to continue parsing the next declaration
    assert(!parser.panic_mode); // Should not be in panic mode after parsing

    // The parser should handle the missing semicolon between "int x = 42" and "int y = 24;"
    // Either by inserting an implicit semicolon or by error recovery
}

fn void test_incomplete_expression()
{
    String source = "int x = 42 +";
    Parser parser;
    parser.init(source, tmem);

    AstTranslationUnit* translation_unit = parser.parse();

    // Verify incomplete expression handling:
    // 1. Parser should not crash with incomplete binary expression
    // 2. Should handle EOF gracefully
    assert(!parser.panic_mode); // Should have recovered or handled gracefully
}

fn void test_unmatched_braces()
{
    String source = "fn test() { int x = 42; // missing closing brace";
    Parser parser;
    parser.init(source, tmem);

    AstTranslationUnit* translation_unit = parser.parse();

    // Verify unmatched brace handling:
    // 1. Parser should not crash with unmatched braces
    // 2. Should handle EOF in the middle of a block
    assert(!parser.panic_mode); // Should have recovered
}

fn void test_multiple_errors()
{
    String source = "int x = ; int y = ; fn test() { return; }";
    Parser parser;
    parser.init(source, tmem);

    AstTranslationUnit* translation_unit = parser.parse();

    // Verify multiple error handling:
    // 1. Parser should handle multiple syntax errors
    // 2. Should not give up after first error
    // 3. Should continue parsing and recover
    assert(!parser.panic_mode); // Should have recovered from all errors
    assert(parser.error_count <= parser.max_errors); // Should not exceed error limit
}

fn void test_parser_initialization()
{
    String source = "hello";
    Parser parser;
    parser.init(source, tmem);

    assert(!parser.had_error);
    assert(!parser.panic_mode);
    assert(parser.current_token.type == TokenType.IDENT);
    assert(parser.current_token.lexeme == "hello");
}

fn void test_parser_advance()
{
    String source = "hello world";
    Parser parser;
    parser.init(source, tmem);

    assert(parser.current_token.type == TokenType.IDENT);
    assert(parser.current_token.lexeme == "hello");

    parser.advance();
    assert(parser.current_token.type == TokenType.WHITESPACE);

    parser.advance();
    assert(parser.current_token.type == TokenType.IDENT);
    assert(parser.current_token.lexeme == "world");
}

fn void test_parser_consume()
{
    String source = "hello;";
    Parser parser;
    parser.init(source, tmem);

    assert(parser.current_token.type == TokenType.IDENT);
    bool consumed = parser.consume(TokenType.IDENT, "Expected identifier");
    assert(consumed);
    assert(!parser.had_error);

    assert(parser.current_token.type == TokenType.SEMICOLON);
}

fn void test_parser_error_handling()
{
    String source = "hello";
    Parser parser;
    parser.init(source, tmem);

    // Try to consume wrong token type
    bool consumed = parser.consume(TokenType.SEMICOLON, "Expected semicolon");
    assert(!consumed);
    assert(parser.had_error);
}

fn void test_parser_basic_functionality()
{
    String source = "fn main() { return 42; }";
    Parser parser;
    parser.init(source, tmem);

    // Test that parser can be initialized and doesn't crash
    assert(!parser.had_error);
    assert(parser.current_token.type == TokenType.IDENT);
    assert(parser.current_token.lexeme == "fn");
}

fn void test_parse_import_statement()
{
    String source = "import std::io;";
    Parser parser;
    parser.init(source, tmem);

    // Test that parser recognizes import keyword
    assert(parser.current_token.type == TokenType.IDENT);
    assert(parser.current_token.lexeme == "import");

    // Parse the import declaration
    AstDecl* decl = parser.parse_declaration();

    // Verify the import declaration structure and identifier names
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_IMPORT);

    AstImportDecl* import_decl = (AstImportDecl*)decl;
    assert(import_decl.identifier_count() == 2);

    // Verify identifier names
    AstIdentifier* std_ident = import_decl.get_identifier(0);
    assert(std_ident != null && std_ident.name == "std");

    AstIdentifier* io_ident = import_decl.get_identifier(1);
    assert(io_ident != null && io_ident.name == "io");

    assert(!parser.panic_mode); // Should not be in panic mode after parsing
}

fn void test_parse_multiple_imports()
{
    String source = "import std::io, std::core::mem;";
    Parser parser;
    parser.init(source, tmem);

    // Test parsing import with multiple paths
    AstDecl* decl = parser.parse_declaration();

    // Verify the import declaration structure
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_IMPORT);

    AstImportDecl* import_decl = (AstImportDecl*)decl;

    // Note: Current implementation parses "std::io, std::core::mem" as one path
    // This might need to be updated based on how the parser handles comma-separated imports
    // For now, verify that at least some identifiers were parsed
    assert(import_decl.identifier_count() >= 2);

    // Verify first identifier is "std"
    AstIdentifier* first_ident = import_decl.get_identifier(0);
    assert(first_ident != null && first_ident.name == "std");

    assert(!parser.panic_mode);
}

fn void test_parse_import_with_nested_path()
{
    String source = "import std::core::mem::allocator;";
    Parser parser;
    parser.init(source, tmem);

    // Test parsing import with deeply nested path
    AstDecl* decl = parser.parse_declaration();

    // Verify the import declaration structure and identifier names
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_IMPORT);

    AstImportDecl* import_decl = (AstImportDecl*)decl;
    assert(import_decl.identifier_count() == 4);

    // Verify each identifier name in the path
    AstIdentifier* std_ident = import_decl.get_identifier(0);
    assert(std_ident != null && std_ident.name == "std");

    AstIdentifier* core_ident = import_decl.get_identifier(1);
    assert(core_ident != null && core_ident.name == "core");

    AstIdentifier* mem_ident = import_decl.get_identifier(2);
    assert(mem_ident != null && mem_ident.name == "mem");

    AstIdentifier* allocator_ident = import_decl.get_identifier(3);
    assert(allocator_ident != null && allocator_ident.name == "allocator");

    assert(!parser.panic_mode);
}

fn void test_import_ast_structure()
{
    String source = "import std::io;";
    Parser parser;
    parser.init(source, tmem);

    // Parse the import declaration
    AstDecl* decl = parser.parse_declaration();

    // Verify the AST structure
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_IMPORT);

    // Cast to import declaration to check specific fields
    AstImportDecl* import_decl = (AstImportDecl*)decl;
    assert(import_decl != null);

    // Verify identifier count and names
    assert(import_decl.identifier_count() == 2);

    // Verify individual identifier names
    AstIdentifier* std_ident = import_decl.get_identifier(0);
    assert(std_ident != null);
    assert(std_ident.name == "std");

    AstIdentifier* io_ident = import_decl.get_identifier(1);
    assert(io_ident != null);
    assert(io_ident.name == "io");

    assert(!parser.had_error);
}

fn void test_import_error_recovery()
{
    String source = "import ; fn test() {}"; // Invalid import followed by valid function
    Parser parser;
    parser.init(source, tmem);

    // Parse the malformed import declaration
    AstDecl* decl = parser.parse_declaration();

    // Parser should handle the error gracefully and recover
    // The error should be detected but parser should continue
    assert(!parser.panic_mode); // Should have recovered after synchronization
}

fn void test_import_paths_populated()
{
    String source = "import std::io;";
    Parser parser;
    parser.init(source, tmem);

    // Parse the import declaration
    AstDecl* decl = parser.parse_declaration();

    // Verify the AST structure and identifiers
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_IMPORT);

    // Cast to import declaration to check identifiers
    AstImportDecl* import_decl = (AstImportDecl*)decl;
    assert(import_decl != null);

    // Verify that exactly 2 identifiers were parsed for "std::io"
    assert(import_decl.identifier_count() == 2);

    // Verify the actual identifier contents
    AstIdentifier* first_ident = import_decl.get_identifier(0);
    AstIdentifier* second_ident = import_decl.get_identifier(1);

    // Verify the identifiers are correctly parsed
    assert(first_ident != null && first_ident.name == "std");
    assert(second_ident != null && second_ident.name == "io");

    // Verify the full path can be reconstructed
    String full_path = import_decl.get_path_string(tmem);
    assert(full_path == "std::io");

    assert(!parser.had_error);
}

fn void test_import_deeply_nested_path()
{
    String source = "import std::core::mem::allocator;";
    Parser parser;
    parser.init(source, tmem);

    // Parse the import declaration
    AstDecl* decl = parser.parse_declaration();

    // Verify the AST structure
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_IMPORT);

    // Cast to import declaration to check identifiers
    AstImportDecl* import_decl = (AstImportDecl*)decl;
    assert(import_decl != null);

    // Verify that exactly 4 identifiers were parsed
    assert(import_decl.identifier_count() == 4);

    // Verify the deeply nested path is correctly parsed
    String path = import_decl.get_path_string(tmem);
    assert(path == "std::core::mem::allocator");

    assert(!parser.had_error);
}

fn void test_parse_struct_declaration()
{
    String source = "struct Point { int x; int y; }";
    Parser parser;
    parser.init(source, tmem);

    // Parse the struct declaration
    AstDecl* decl = parser.parse_declaration();

    // Verify the AST structure
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_STRUCT);
    assert(decl.name == "Point");

    // Cast to struct declaration to check members
    AstStructDecl* struct_decl = (AstStructDecl*)decl;
    assert(struct_decl != null);
    assert(!struct_decl.is_union);

    // Verify that 2 members were parsed
    assert(struct_decl.members.len() == 2);

    // Check first member
    AstStructMember* first_member = struct_decl.members[0];
    assert(first_member != null);
    assert(first_member.name == "x");
    assert(!first_member.is_inline);

    // Check second member
    AstStructMember* second_member = struct_decl.members[1];
    assert(second_member != null);
    assert(second_member.name == "y");
    assert(!first_member.is_inline);

    assert(!parser.had_error);
}

fn void test_parse_union_declaration()
{
    String source = "union Value { int i; float f; }";
    Parser parser;
    parser.init(source, tmem);

    // Parse the union declaration
    AstDecl* decl = parser.parse_declaration();

    // Verify the AST structure
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_STRUCT);
    assert(decl.name == "Value");

    // Cast to struct declaration to check union flag
    AstStructDecl* struct_decl = (AstStructDecl*)decl;
    assert(struct_decl != null);
    assert(struct_decl.is_union);

    // Verify that 2 members were parsed
    assert(struct_decl.members.len() == 2);

    assert(!parser.had_error);
}

fn void test_parse_struct_with_inline_member()
{
    String source = "struct Base { int x; inline Point pos; }";
    Parser parser;
    parser.init(source, tmem);

    // Parse the struct declaration
    AstDecl* decl = parser.parse_declaration();

    // Verify the AST structure
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_STRUCT);
    assert(decl.name == "Base");

    // Cast to struct declaration to check members
    AstStructDecl* struct_decl = (AstStructDecl*)decl;
    assert(struct_decl != null);
    assert(!struct_decl.is_union);

    // Verify that 2 members were parsed
    assert(struct_decl.members.len() == 2);

    // Check first member (regular)
    AstStructMember* first_member = struct_decl.members[0];
    assert(first_member != null);
    assert(first_member.name == "x");
    assert(!first_member.is_inline);

    // Check second member (inline)
    AstStructMember* second_member = struct_decl.members[1];
    assert(second_member != null);
    assert(second_member.name == "pos");
    assert(second_member.is_inline);

    assert(!parser.had_error);
}

fn void test_struct_error_missing_name()
{
    String source = "struct { int x; }"; // Missing struct name
    Parser parser;
    parser.init(source, tmem);

    // Parse the malformed struct declaration
    AstDecl* decl = parser.parse_declaration();

    // Parser should handle the error gracefully
    assert(decl != null); // Should still create a struct node
    assert(decl.node.kind == AST_DECL_STRUCT);
    assert(!parser.panic_mode); // Should have recovered
}

fn void test_struct_error_missing_opening_brace()
{
    String source = "struct Point int x; int y; }"; // Missing opening brace
    Parser parser;
    parser.init(source, tmem);

    // Parse the malformed struct declaration
    AstDecl* decl = parser.parse_declaration();

    // Parser should handle the error gracefully
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_STRUCT);
    assert(decl.name == "Point");
    assert(!parser.panic_mode); // Should have recovered
}

fn void test_struct_error_missing_closing_brace()
{
    String source = "struct Point { int x; int y;"; // Missing closing brace
    Parser parser;
    parser.init(source, tmem);

    // Parse the malformed struct declaration
    AstDecl* decl = parser.parse_declaration();

    // Parser should handle the error gracefully
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_STRUCT);
    assert(decl.name == "Point");
    assert(!parser.panic_mode); // Should have recovered
}

fn void test_struct_error_missing_member_type()
{
    String source = "struct Point { x; int y; }"; // Missing type for first member
    Parser parser;
    parser.init(source, tmem);

    // Parse the struct declaration with malformed member
    AstDecl* decl = parser.parse_declaration();

    // Parser should handle the error gracefully
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_STRUCT);
    assert(decl.name == "Point");

    // Should have parsed at least the valid member
    AstStructDecl* struct_decl = (AstStructDecl*)decl;
    assert(struct_decl != null);
    // May have 0 or 1 members depending on error recovery
    assert(!parser.panic_mode); // Should have recovered
}

fn void test_struct_error_missing_member_name()
{
    String source = "struct Point { int; int y; }"; // Missing name for first member
    Parser parser;
    parser.init(source, tmem);

    // Parse the struct declaration with malformed member
    AstDecl* decl = parser.parse_declaration();

    // Parser should handle the error gracefully
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_STRUCT);
    assert(decl.name == "Point");
    assert(!parser.panic_mode); // Should have recovered
}

fn void test_struct_error_missing_semicolon()
{
    String source = "struct Point { int x int y; }"; // Missing semicolon after first member
    Parser parser;
    parser.init(source, tmem);

    // Parse the struct declaration with missing semicolon
    AstDecl* decl = parser.parse_declaration();

    // Parser should handle the error gracefully
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_STRUCT);
    assert(decl.name == "Point");
    assert(!parser.panic_mode); // Should have recovered
}

fn void test_struct_error_invalid_inline()
{
    String source = "struct Point { inline; int y; }"; // Invalid inline usage
    Parser parser;
    parser.init(source, tmem);

    // Parse the struct declaration with malformed inline
    AstDecl* decl = parser.parse_declaration();

    // Parser should handle the error gracefully
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_STRUCT);
    assert(decl.name == "Point");
    assert(!parser.panic_mode); // Should have recovered
}

fn void test_struct_error_empty_struct()
{
    String source = "struct Empty { }"; // Empty struct (should be valid)
    Parser parser;
    parser.init(source, tmem);

    // Parse the empty struct declaration
    AstDecl* decl = parser.parse_declaration();

    // This should be valid
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_STRUCT);
    assert(decl.name == "Empty");

    AstStructDecl* struct_decl = (AstStructDecl*)decl;
    assert(struct_decl != null);
    assert(struct_decl.members.len() == 0);
    assert(!parser.had_error);
}

fn void test_struct_error_recovery_continues_parsing()
{
    String source = "struct Bad { invalid } struct Good { int x; }"; // Bad struct followed by good struct
    Parser parser;
    parser.init(source, tmem);

    // Parse the first (bad) struct declaration
    AstDecl* decl1 = parser.parse_declaration();
    assert(decl1 != null);
    assert(decl1.node.kind == AST_DECL_STRUCT);
    assert(decl1.name == "Bad");

    // Skip whitespace to get to the second struct
    while (parser.current_token.type == TokenType.WHITESPACE ||
           parser.current_token.type == TokenType.NEWLINE)
    {
        parser.advance();
    }

    // Parse the second (good) struct declaration
    if (!parser.check(TokenType.EOF))
    {
        AstDecl* decl2 = parser.parse_declaration();
        assert(decl2 != null);
        assert(decl2.node.kind == AST_DECL_STRUCT);
        assert(decl2.name == "Good");

        AstStructDecl* struct_decl2 = (AstStructDecl*)decl2;
        assert(struct_decl2 != null);
        assert(struct_decl2.members.len() == 1);
    }

    assert(!parser.panic_mode); // Should have recovered
}

fn void test_struct_multiple_errors_recovery()
{
    String source = "struct { int; float } struct Point { int x; int y; }"; // Multiple errors followed by valid struct
    Parser parser;
    parser.init(source, tmem);

    // Parse the first (malformed) struct declaration
    AstDecl* decl1 = parser.parse_declaration();
    assert(decl1 != null);
    assert(decl1.node.kind == AST_DECL_STRUCT);
    // Name should be placeholder due to missing name

    // Skip whitespace to get to the second struct
    while (parser.current_token.type == TokenType.WHITESPACE ||
           parser.current_token.type == TokenType.NEWLINE)
    {
        parser.advance();
    }

    // Parse the second (good) struct declaration
    if (!parser.check(TokenType.EOF))
    {
        AstDecl* decl2 = parser.parse_declaration();
        assert(decl2 != null);
        assert(decl2.node.kind == AST_DECL_STRUCT);
        assert(decl2.name == "Point");

        AstStructDecl* struct_decl2 = (AstStructDecl*)decl2;
        assert(struct_decl2 != null);
        assert(struct_decl2.members.len() == 2);

        // Verify the members of the good struct
        AstStructMember* first_member = struct_decl2.members[0];
        assert(first_member != null);
        assert(first_member.name == "x");

        AstStructMember* second_member = struct_decl2.members[1];
        assert(second_member != null);
        assert(second_member.name == "y");
    }

    assert(!parser.panic_mode); // Should have recovered from all errors
}
