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
    AstTranslationUnit translation_unit;
    translation_unit.init("test.c3", tmem);

    assert(translation_unit.node.kind == AST_TRANSLATION_UNIT);
    assert(translation_unit.filename == "test.c3");
    assert(translation_unit.declaration_count() == 0);

    // Create and add a declaration
    AstImportDecl import_decl;
    import_decl.init(tmem);

    translation_unit.add_declaration((AstDecl*)&import_decl);

    assert(translation_unit.declaration_count() == 1);
    assert(translation_unit.get_declaration(0) == (AstDecl*)&import_decl);
    assert(import_decl.decl.node.parent == (AstNode*)&translation_unit);
}
