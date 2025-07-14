module parser::tests @test;
import parser;

/**
 * Test the new AST structure with TranslationUnit root and bidirectional traversal
 */

fn void test_translation_unit_creation()
{
    String source = "import std::io;";
    Parser parser;
    parser.init(source, tmem);

    // Parse into a TranslationUnit
    AstTranslationUnit* translation_unit = parser.parse("test.c3");

    // Verify the translation unit structure
    assert(translation_unit != null);
    assert(translation_unit.node.kind == AST_TRANSLATION_UNIT);
    assert(translation_unit.filename == "test.c3");
    assert(translation_unit.node.parent == null); // Root has no parent
    assert(translation_unit.declaration_count() == 1);
}

fn void test_import_with_identifier_nodes()
{
    String source = "import std::io::file;";
    Parser parser;
    parser.init(source, tmem);

    // Parse into a TranslationUnit
    AstTranslationUnit* translation_unit = parser.parse("test.c3");

    // Get the import declaration
    AstDecl* decl = translation_unit.get_declaration(0);
    assert(decl != null);
    assert(decl.node.kind == AST_DECL_IMPORT);

    // Cast to import declaration
    AstImportDecl* import_decl = (AstImportDecl*)decl;
    assert(import_decl != null);

    // Verify identifier count and structure
    assert(import_decl.identifier_count() == 3);

    // Check individual identifiers
    AstIdentifier* std_ident = import_decl.get_identifier(0);
    assert(std_ident != null);
    assert(std_ident.name == "std");
    assert(std_ident.expr.node.kind == AST_EXPR_IDENTIFIER);

    AstIdentifier* io_ident = import_decl.get_identifier(1);
    assert(io_ident != null);
    assert(io_ident.name == "io");

    AstIdentifier* file_ident = import_decl.get_identifier(2);
    assert(file_ident != null);
    assert(file_ident.name == "file");

    // Test path string reconstruction
    String full_path = import_decl.get_path_string(tmem);
    assert(full_path == "std::io::file");
}

fn void test_parent_child_relationships()
{
    String source = "import std::io;";
    Parser parser;
    parser.init(source, tmem);

    // Parse into a TranslationUnit
    AstTranslationUnit* translation_unit = parser.parse("test.c3");

    // Get the import declaration
    AstDecl* decl = translation_unit.get_declaration(0);
    assert(decl != null);

    // Verify parent relationship
    assert(decl.node.parent == (AstNode*)translation_unit);

    // Cast to import declaration and check identifier parents
    AstImportDecl* import_decl = (AstImportDecl*)decl;
    
    for (usz i = 0; i < import_decl.identifier_count(); i++)
    {
        AstIdentifier* ident = import_decl.get_identifier(i);
        assert(ident != null);
        assert(ident.expr.node.parent == (AstNode*)import_decl);
    }
}

fn void test_bidirectional_traversal()
{
    String source = "import std::io::file;";
    Parser parser;
    parser.init(source, tmem);

    // Parse into a TranslationUnit
    AstTranslationUnit* translation_unit = parser.parse("test.c3");

    // Get the import declaration
    AstDecl* decl = translation_unit.get_declaration(0);
    AstImportDecl* import_decl = (AstImportDecl*)decl;

    // Test traversal from identifier to root
    AstIdentifier* file_ident = import_decl.get_identifier(2);
    assert(file_ident != null);

    // Get root from identifier
    AstTranslationUnit* root = file_ident.expr.node.get_root();
    assert(root != null);
    assert(root == translation_unit);

    // Test ancestor checking
    assert(translation_unit.node.is_ancestor_of((AstNode*)import_decl));
    assert(import_decl.decl.node.is_ancestor_of((AstNode*)file_ident));
    assert(translation_unit.node.is_ancestor_of((AstNode*)file_ident));
    assert(!file_ident.expr.node.is_ancestor_of((AstNode*)import_decl));
}

fn void test_common_ancestor()
{
    String source = "import std::io, std::core::mem;";
    Parser parser;
    parser.init(source, tmem);

    // Parse into a TranslationUnit
    AstTranslationUnit* translation_unit = parser.parse("test.c3");

    // This should create one import with multiple identifier paths
    // For now, let's test with a single import that has multiple identifiers
    AstDecl* decl = translation_unit.get_declaration(0);
    AstImportDecl* import_decl = (AstImportDecl*)decl;

    if (import_decl.identifier_count() >= 2)
    {
        AstIdentifier* first_ident = import_decl.get_identifier(0);
        AstIdentifier* second_ident = import_decl.get_identifier(1);

        // Find common ancestor
        AstNode* common = first_ident.expr.node.find_common_ancestor((AstNode*)second_ident);
        assert(common != null);
        assert(common == (AstNode*)import_decl);
    }
}

fn void test_multiple_declarations()
{
    String source = "import std::io; struct Point { int x; int y; }";
    Parser parser;
    parser.init(source, tmem);

    // Parse into a TranslationUnit
    AstTranslationUnit* translation_unit = parser.parse("test.c3");

    // Should have 2 declarations
    assert(translation_unit.declaration_count() == 2);

    // Check first declaration (import)
    AstDecl* import_decl = translation_unit.get_declaration(0);
    assert(import_decl != null);
    assert(import_decl.node.kind == AST_DECL_IMPORT);
    assert(import_decl.node.parent == (AstNode*)translation_unit);

    // Check second declaration (struct)
    AstDecl* struct_decl = translation_unit.get_declaration(1);
    assert(struct_decl != null);
    assert(struct_decl.node.kind == AST_DECL_STRUCT);
    assert(struct_decl.node.parent == (AstNode*)translation_unit);
}

fn void test_empty_translation_unit()
{
    String source = "";
    Parser parser;
    parser.init(source, tmem);

    // Parse empty source
    AstTranslationUnit* translation_unit = parser.parse("empty.c3");

    // Should have valid translation unit with no declarations
    assert(translation_unit != null);
    assert(translation_unit.node.kind == AST_TRANSLATION_UNIT);
    assert(translation_unit.filename == "empty.c3");
    assert(translation_unit.declaration_count() == 0);
}

fn void test_ast_node_member_functions()
{
    String source = "import std::io;";
    Parser parser;
    parser.init(source, tmem);

    // Parse into a TranslationUnit
    AstTranslationUnit* translation_unit = parser.parse("test.c3");

    // Get the import declaration
    AstDecl* decl = translation_unit.get_declaration(0);
    AstImportDecl* import_decl = (AstImportDecl*)decl;
    AstIdentifier* ident = import_decl.get_identifier(0);

    // Test set_parent function
    AstNode dummy_node;
    dummy_node.kind = AST_POISONED;
    dummy_node.parent = null;

    ident.expr.node.set_parent(&dummy_node);
    assert(ident.expr.node.parent == &dummy_node);

    // Restore original parent
    ident.expr.node.set_parent((AstNode*)import_decl);
    assert(ident.expr.node.parent == (AstNode*)import_decl);
}

fn void test_import_decl_member_functions()
{
    // Test ImportDecl member functions directly
    AstImportDecl import_decl;
    import_decl.init(tmem);

    assert(import_decl.identifier_count() == 0);

    // Create and add identifiers
    AstIdentifier std_ident;
    std_ident.expr.node.kind = AST_EXPR_IDENTIFIER;
    std_ident.name = "std";

    AstIdentifier io_ident;
    io_ident.expr.node.kind = AST_EXPR_IDENTIFIER;
    io_ident.name = "io";

    import_decl.add_identifier(&std_ident);
    import_decl.add_identifier(&io_ident);

    assert(import_decl.identifier_count() == 2);
    assert(import_decl.get_identifier(0) == &std_ident);
    assert(import_decl.get_identifier(1) == &io_ident);

    // Test path string generation
    String path = import_decl.get_path_string(tmem);
    assert(path == "std::io");
}

fn void test_translation_unit_member_functions()
{
    // Test TranslationUnit member functions directly
    String test_source = "import std::io;\nstruct Point { int x; }";
    AstTranslationUnit translation_unit;
    translation_unit.init("test.c3", test_source, tmem);

    assert(translation_unit.node.kind == AST_TRANSLATION_UNIT);
    assert(translation_unit.filename == "test.c3");
    assert(translation_unit.source_text == test_source);
    assert(translation_unit.declaration_count() == 0);

    // Create and add a declaration
    AstImportDecl import_decl;
    import_decl.init(tmem);

    translation_unit.add_declaration((AstDecl*)&import_decl);

    assert(translation_unit.declaration_count() == 1);
    assert(translation_unit.get_declaration(0) == (AstDecl*)&import_decl);
    assert(import_decl.decl.node.parent == (AstNode*)&translation_unit);
}

fn void test_line_mapping()
{
    String source = "import std::io;\nstruct Point {\n  int x;\n  int y;\n}";
    AstTranslationUnit translation_unit;
    translation_unit.init("test.c3", source, tmem);

    // Test line map was built correctly
    // "import std::io;\n" = 16 chars, newline at 15
    // "struct Point {\n" = 15 chars, newline at 30
    // "  int x;\n" = 9 chars, newline at 39
    // "  int y;\n" = 9 chars, newline at 48
    // "}" = 1 char
    assert(translation_unit.line_map.len() == 5); // 5 lines (0-4)
    assert(translation_unit.line_map[0] == 0);    // Line 0 starts at offset 0
    assert(translation_unit.line_map[1] == 16);   // Line 1 starts after "import std::io;\n"
    assert(translation_unit.line_map[2] == 31);   // Line 2 starts after "struct Point {\n"
    assert(translation_unit.line_map[3] == 40);   // Line 3 starts after "  int x;\n"
    assert(translation_unit.line_map[4] == 49);   // Line 4 starts after "  int y;\n"
}

fn void test_position_conversion()
{
    String source = "import std::io;\nstruct Point {\n  int x;\n}";
    AstTranslationUnit translation_unit;
    translation_unit.init("test.c3", source, tmem);

    // Test offset to position conversion
    SourcePosition pos0 = translation_unit.offset_to_position(0);
    assert(pos0.line == 0 && pos0.column == 0);

    SourcePosition pos7 = translation_unit.offset_to_position(7);  // "std" in "import std::io;"
    assert(pos7.line == 0 && pos7.column == 7);

    SourcePosition pos16 = translation_unit.offset_to_position(16); // Start of line 1
    assert(pos16.line == 1 && pos16.column == 0);

    SourcePosition pos23 = translation_unit.offset_to_position(23); // "Point" in "struct Point {"
    assert(pos23.line == 1 && pos23.column == 7);

    // Test position to offset conversion
    SourcePosition test_pos = { .line = 0, .column = 7 };
    uint offset = translation_unit.position_to_offset(test_pos);
    assert(offset == 7);

    test_pos = { .line = 1, .column = 7 };
    offset = translation_unit.position_to_offset(test_pos);
    assert(offset == 23);
}

fn void test_find_node_at_position()
{
    String source = "import std::io;";
    Parser parser;
    parser.init(source, tmem);

    // Parse into a TranslationUnit with proper AST nodes
    AstTranslationUnit* translation_unit = parser.parse("test.c3");

    // First, let's verify the AST structure and spans
    assert(translation_unit.declaration_count() == 1);
    AstDecl* import_decl = translation_unit.get_declaration(0);
    assert(import_decl != null);
    assert(import_decl.node.kind == AST_DECL_IMPORT);

    // Verify import declaration has proper span
    assert(import_decl.node.span.start == 0); // Should start at "import"
    assert(import_decl.node.span.end == 15);  // Should end at ";"

    // Check identifier spans
    AstImportDecl* import_ast = (AstImportDecl*)import_decl;
    assert(import_ast.identifier_count() == 2);

    AstIdentifier* std_ident = import_ast.get_identifier(0);
    assert(std_ident != null);
    assert(std_ident.name == "std");
    // "std" should be at position 7-9 in "import std::io;"
    assert(std_ident.expr.node.span.start == 7);
    assert(std_ident.expr.node.span.end == 10);

    AstIdentifier* io_ident = import_ast.get_identifier(1);
    assert(io_ident != null);
    assert(io_ident.name == "io");
    // "io" should be at position 12-13 in "import std::io;"
    assert(io_ident.expr.node.span.start == 12);
    assert(io_ident.expr.node.span.end == 14);

    // Now test position finding
    // Position at "std" identifier (column 7)
    SourcePosition std_pos = { .line = 0, .column = 7 };
    AstNode* node_at_std = translation_unit.find_node_at_position(std_pos);
    assert(node_at_std != null);
    assert(node_at_std.kind == AST_EXPR_IDENTIFIER);

    // Position at "io" identifier (column 12)
    SourcePosition io_pos = { .line = 0, .column = 12 };
    AstNode* node_at_io = translation_unit.find_node_at_position(io_pos);
    assert(node_at_io != null);
    assert(node_at_io.kind == AST_EXPR_IDENTIFIER);
}
