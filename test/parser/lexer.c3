module parser::tests @test;
import parser;

fn void test_comma()
{
    String source = ",";
    Lexer lexer;
    lexer.init(source);

    Token token = lexer.lexer_next_token();
    assert(token.type == TokenType.COMMA);
    assert(token.lexeme.len == 1);
    assert(token.span.start == 0);
    assert(token.span.end == 1);

    // Next token should be EOF
    Token eof_token = lexer.lexer_next_token();
    assert(eof_token.type == TokenType.EOF);
}

fn void test_multiple_tokens()
{
    String source = "{,}";
    Lexer lexer;
    lexer.init(source);
    
    // First token: {
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.LBRACE);
    
    // Second token: ,
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.COMMA);
    
    // Third token: }
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.RBRACE);
    
    // Fourth token: EOF
    Token eof_token = lexer.lexer_next_token();
    assert(eof_token.type == TokenType.EOF);
}

fn void test_whitespace()
{
    String source = ", \t,";
    Lexer lexer;
    lexer.init(source);
    
    // First token: ,
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.COMMA);
    
    // Second token: whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);
    assert(token2.lexeme.len == 2); // space + tab
    
    // Third token: ,
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.COMMA);
}

fn void test_newline()
{
    String source = ",\n,";
    Lexer lexer;
    lexer.init(source);

    // First token: , (at position 0)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.COMMA);
    assert(token1.span.start == 0);
    assert(token1.span.end == 1);

    // Second token: newline (at position 1)
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.NEWLINE);
    assert(token2.span.start == 1);
    assert(token2.span.end == 2);

    // Third token: , (at position 2)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.COMMA);
    assert(token3.span.start == 2);
    assert(token3.span.end == 3);
}

fn void test_absolute_positions()
{
    String source = "hello -> world";
    Lexer lexer;
    lexer.init(source);

    // First token: "hello" (positions 0-5)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.IDENT);
    assert(token1.span.start == 0);
    assert(token1.span.end == 5);
    assert(token1.lexeme == "hello");

    // Second token: whitespace (position 5-6)
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);
    assert(token2.span.start == 5);
    assert(token2.span.end == 6);

    // Third token: "->" (positions 6-8)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.ARROW);
    assert(token3.span.start == 6);
    assert(token3.span.end == 8);
    assert(token3.lexeme == "->");

    // Fourth token: whitespace (position 8-9)
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);
    assert(token4.span.start == 8);
    assert(token4.span.end == 9);

    // Fifth token: "world" (positions 9-14)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.IDENT);
    assert(token5.span.start == 9);
    assert(token5.span.end == 14);
    assert(token5.lexeme == "world");
}

fn void test_multi_char_tokens()
{
    String source = ":: .. ... == != <= >= && ||";
    Lexer lexer;
    lexer.init(source);
    
    TokenType[] expected = {
        TokenType.SCOPE,      // ::
        TokenType.WHITESPACE, // space
        TokenType.DOTDOT,     // ..
        TokenType.WHITESPACE, // space
        TokenType.ELLIPSIS,   // ...
        TokenType.WHITESPACE, // space
        TokenType.EQEQ,       // ==
        TokenType.WHITESPACE, // space
        TokenType.NOT_EQUAL,  // !=
        TokenType.WHITESPACE, // space
        TokenType.LESS_EQ,    // <=
        TokenType.WHITESPACE, // space
        TokenType.GREATER_EQ, // >=
        TokenType.WHITESPACE, // space
        TokenType.AND,        // &&
        TokenType.WHITESPACE, // space
        TokenType.OR,         // ||
        TokenType.EOF
    };
    
    foreach (i, expected_type : expected)
    {
        Token token = lexer.lexer_next_token();
        assert(token.type == expected_type, "Token %d: expected %d, got %d", i, expected_type, token.type);
    }
}

fn void test_comments()
{
    String source = "// line comment\n/* block comment */";
    Lexer lexer;
    lexer.init(source);
    
    // First token: line comment
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.COMMENT_LINE);
    
    // Second token: newline
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.NEWLINE);
    
    // Third token: block comment
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.COMMENT_BLOCK);
}

fn void test_assignment_operators()
{
    String source = "+= -= *= /= %= &= |= ^= <<= >>=";
    Lexer lexer;
    lexer.init(source);
    
    TokenType[] expected = {
        TokenType.PLUS_ASSIGN,    // +=
        TokenType.WHITESPACE,     // space
        TokenType.MINUS_ASSIGN,   // -=
        TokenType.WHITESPACE,     // space
        TokenType.MULT_ASSIGN,    // *=
        TokenType.WHITESPACE,     // space
        TokenType.DIV_ASSIGN,     // /=
        TokenType.WHITESPACE,     // space
        TokenType.MOD_ASSIGN,     // %=
        TokenType.WHITESPACE,     // space
        TokenType.BIT_AND_ASSIGN, // &=
        TokenType.WHITESPACE,     // space
        TokenType.BIT_OR_ASSIGN,  // |=
        TokenType.WHITESPACE,     // space
        TokenType.BIT_XOR_ASSIGN, // ^=
        TokenType.WHITESPACE,     // space
        TokenType.SHL_ASSIGN,     // <<=
        TokenType.WHITESPACE,     // space
        TokenType.SHR_ASSIGN,     // >>=
        TokenType.EOF
    };
    
    foreach (i, expected_type : expected)
    {
        Token token = lexer.lexer_next_token();
        assert(token.type == expected_type, "Token %d: expected %d, got %d", i, expected_type, token.type);
    }
}

fn void test_increment_decrement()
{
    String source = "++ --";
    Lexer lexer;
    lexer.init(source);
    
    // First token: ++
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.PLUSPLUS);
    
    // Second token: whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);
    
    // Third token: --
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.MINUSMINUS);
}

fn void test_shift_operators()
{
    String source = "<< >>";
    Lexer lexer;
    lexer.init(source);
    
    // First token: <<
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.SHL);
    
    // Second token: whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);
    
    // Third token: >>
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.SHR);
}

fn void test_arrow_operator()
{
    String source = "->";
    Lexer lexer;
    lexer.init(source);
    
    Token token = lexer.lexer_next_token();
    assert(token.type == TokenType.ARROW);
    assert(token.lexeme == "->");
}

fn void test_single_char_tokens()
{
    String source = "()[]{}.,;:?!~+-*/%&|^< > = @#$";
    Lexer lexer;
    lexer.init(source);
    
    TokenType[] expected = {
        TokenType.LPAREN,    // (
        TokenType.RPAREN,    // )
        TokenType.LBRACKET,  // [
        TokenType.RBRACKET,  // ]
        TokenType.LBRACE,    // {
        TokenType.RBRACE,    // }
        TokenType.DOT,       // .
        TokenType.COMMA,     // ,
        TokenType.SEMICOLON, // ;
        TokenType.COLON,     // :
        TokenType.QUESTION,  // ?
        TokenType.BANG,      // !
        TokenType.TILDE,     // ~
        TokenType.PLUS,      // +
        TokenType.MINUS,     // -
        TokenType.STAR,      // *
        TokenType.SLASH,     // /
        TokenType.PERCENT,   // %
        TokenType.AMPERSAND, // &
        TokenType.PIPE,      // |
        TokenType.CARET,     // ^
        TokenType.LESS,      // <
        TokenType.WHITESPACE, // space
        TokenType.GREATER,   // >
        TokenType.WHITESPACE, // space
        TokenType.EQUAL,     // =
        TokenType.WHITESPACE, // space
        TokenType.AT,        // @
        TokenType.HASH,      // #
        TokenType.DOLLAR,    // $
        TokenType.EOF
    };
    
    foreach (i, expected_type : expected)
    {
        Token token = lexer.lexer_next_token();
        assert(token.type == expected_type, "Token %d: expected %d, got %d", i, expected_type, token.type);
    }
}

fn void test_at_identifiers()
{
    String source = "@macro @MACRO @Macro @ @_test @Test_Case";
    Lexer lexer;
    lexer.init(source);

    // @macro (normal identifier)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.AT_IDENT);
    assert(token1.lexeme == "@macro");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // @MACRO (const identifier)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.AT_CONST_IDENT);
    assert(token3.lexeme == "@MACRO");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // @Macro (type identifier)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.AT_TYPE_IDENT);
    assert(token5.lexeme == "@Macro");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // @ (standalone at symbol)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.AT);
    assert(token7.lexeme == "@");

    // whitespace
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.WHITESPACE);

    // @_test (normal identifier starting with underscore)
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.AT_IDENT);
    assert(token9.lexeme == "@_test");

    // whitespace
    Token token10 = lexer.lexer_next_token();
    assert(token10.type == TokenType.WHITESPACE);

    // @Test_Case (type identifier with underscore)
    Token token11 = lexer.lexer_next_token();
    assert(token11.type == TokenType.AT_TYPE_IDENT);
    assert(token11.lexeme == "@Test_Case");
}

fn void test_at_identifier_edge_cases()
{
    String source = "@123 @_ @__";
    Lexer lexer;
    lexer.init(source);

    // @123 (invalid - starts with digit)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.INVALID_TOKEN);

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // @_ (invalid - only underscore)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.INVALID_TOKEN);

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // @__ (invalid - only underscores)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.INVALID_TOKEN);
}

fn void test_char_literals()
{
    String source = "'a' 'Z' '0' '\\n' '\\t' '\\\\' '\\''";
    Lexer lexer;
    lexer.init(source);

    // 'a'
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.CHAR_LITERAL);
    assert(token1.lexeme == "'a'");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // 'Z'
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.CHAR_LITERAL);
    assert(token3.lexeme == "'Z'");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // '0'
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.CHAR_LITERAL);
    assert(token5.lexeme == "'0'");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // '\n'
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.CHAR_LITERAL);
    assert(token7.lexeme == "'\\n'");

    // whitespace
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.WHITESPACE);

    // '\t'
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.CHAR_LITERAL);
    assert(token9.lexeme == "'\\t'");

    // whitespace
    Token token10 = lexer.lexer_next_token();
    assert(token10.type == TokenType.WHITESPACE);

    // '\\'
    Token token11 = lexer.lexer_next_token();
    assert(token11.type == TokenType.CHAR_LITERAL);
    assert(token11.lexeme == "'\\\\'");

    // whitespace
    Token token12 = lexer.lexer_next_token();
    assert(token12.type == TokenType.WHITESPACE);

    // '\''
    Token token13 = lexer.lexer_next_token();
    assert(token13.type == TokenType.CHAR_LITERAL);
    assert(token13.lexeme == "'\\''");
}

fn void test_char_hex_escape()
{
    String source = "'\\x41' '\\x7F' '\\x00'";
    Lexer lexer;
    lexer.init(source);

    // '\x41' (ASCII 'A')
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.CHAR_LITERAL);
    assert(token1.lexeme == "'\\x41'");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // '\x7F'
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.CHAR_LITERAL);
    assert(token3.lexeme == "'\\x7F'");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // '\x00'
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.CHAR_LITERAL);
    assert(token5.lexeme == "'\\x00'");
}

fn void test_char_unicode_escape()
{
    String source = "'\\u0041' '\\U00000041'";
    Lexer lexer;
    lexer.init(source);

    // '\u0041' (Unicode 'A')
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.CHAR_LITERAL);
    assert(token1.lexeme == "'\\u0041'");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // '\U00000041'
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.CHAR_LITERAL);
    assert(token3.lexeme == "'\\U00000041'");
}

fn void test_char_literal_errors()
{
    String source = "'' '\\x' '\\u123' 'abc";
    Lexer lexer;
    lexer.init(source);

    // '' (empty)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.INVALID_TOKEN);

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // '\x' (incomplete hex escape)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.INVALID_TOKEN);

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // '\u123' (incomplete unicode escape)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.INVALID_TOKEN);

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // 'abc (unterminated)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.INVALID_TOKEN);
}

fn void test_raw_strings()
{
    String source = "`hello` `world with spaces` `line1\nline2`";
    Lexer lexer;
    lexer.init(source);

    // `hello`
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.STRING);
    assert(token1.lexeme == "`hello`");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // `world with spaces`
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.STRING);
    assert(token3.lexeme == "`world with spaces`");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // `line1\nline2` (with actual newline)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.STRING);
    assert(token5.lexeme == "`line1\nline2`");
}

fn void test_raw_string_escaped_backticks()
{
    String source = "`hello``world` `back``tick``here`";
    Lexer lexer;
    lexer.init(source);

    // `hello``world` (contains escaped backtick)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.STRING);
    assert(token1.lexeme == "`hello``world`");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // `back``tick``here` (multiple escaped backticks)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.STRING);
    assert(token3.lexeme == "`back``tick``here`");
}

fn void test_raw_string_special_chars()
{
    String source = "`quotes\"'` `backslash\\` `tab\there`";
    Lexer lexer;
    lexer.init(source);

    // `quotes"'` (contains quotes)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.STRING);
    assert(token1.lexeme == "`quotes\"'`");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // `backslash\` (contains backslash)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.STRING);
    assert(token3.lexeme == "`backslash\\`");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // `tab	here` (contains actual tab)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.STRING);
    assert(token5.lexeme == "`tab\there`");
}

fn void test_raw_string_empty()
{
    String source = "`` `a` ``";
    Lexer lexer;
    lexer.init(source);

    // `` (empty raw string)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.STRING);
    assert(token1.lexeme == "``");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // `a`
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.STRING);
    assert(token3.lexeme == "`a`");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // `` (another empty raw string)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.STRING);
    assert(token5.lexeme == "``");
}

fn void test_raw_string_errors()
{
    String source = "`unterminated";
    Lexer lexer;
    lexer.init(source);

    // `unterminated (no closing backtick)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.INVALID_TOKEN);
}

fn void test_strings()
{
    String source = "\"hello\" \"world with spaces\" \"\"";
    Lexer lexer;
    lexer.init(source);

    // "hello"
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.STRING);
    assert(token1.lexeme == "\"hello\"");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // "world with spaces"
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.STRING);
    assert(token3.lexeme == "\"world with spaces\"");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // "" (empty string)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.STRING);
    assert(token5.lexeme == "\"\"");
}

fn void test_string_escape_sequences()
{
    String source = "\"\\n\" \"\\t\" \"\\\\\" \"\\\"\" \"\\r\" \"\\0\"";
    Lexer lexer;
    lexer.init(source);

    // "\n"
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.STRING);
    assert(token1.lexeme == "\"\\n\"");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // "\t"
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.STRING);
    assert(token3.lexeme == "\"\\t\"");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // "\\"
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.STRING);
    assert(token5.lexeme == "\"\\\\\"");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // "\""
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.STRING);
    assert(token7.lexeme == "\"\\\"\"");

    // whitespace
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.WHITESPACE);

    // "\r"
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.STRING);
    assert(token9.lexeme == "\"\\r\"");

    // whitespace
    Token token10 = lexer.lexer_next_token();
    assert(token10.type == TokenType.WHITESPACE);

    // "\0"
    Token token11 = lexer.lexer_next_token();
    assert(token11.type == TokenType.STRING);
    assert(token11.lexeme == "\"\\0\"");
}

fn void test_string_hex_escape()
{
    String source = "\"\\x41\" \"\\x7F\" \"\\x00\"";
    Lexer lexer;
    lexer.init(source);

    // "\x41" (ASCII 'A')
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.STRING);
    assert(token1.lexeme == "\"\\x41\"");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // "\x7F"
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.STRING);
    assert(token3.lexeme == "\"\\x7F\"");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // "\x00"
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.STRING);
    assert(token5.lexeme == "\"\\x00\"");
}

fn void test_string_unicode_escape()
{
    String source = "\"\\u0041\" \"\\U00000041\"";
    Lexer lexer;
    lexer.init(source);

    // "\u0041" (Unicode 'A')
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.STRING);
    assert(token1.lexeme == "\"\\u0041\"");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // "\U00000041"
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.STRING);
    assert(token3.lexeme == "\"\\U00000041\"");
}

fn void test_string_line_continuation()
{
    String source = "\"line1\\\nline2\"";
    Lexer lexer;
    lexer.init(source);

    // "line1\
    // line2" (with line continuation)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.STRING);
    assert(token1.lexeme == "\"line1\\\nline2\"");
}

fn void test_string_errors()
{
    // Test unterminated string
    String source1 = "\"unterminated";
    Lexer lexer1;
    lexer1.init(source1);

    Token token1 = lexer1.lexer_next_token();
    assert(token1.type == TokenType.INVALID_TOKEN);

    // Test string with newline
    String source2 = "\"newline\nhere\"";
    Lexer lexer2;
    lexer2.init(source2);

    Token token2 = lexer2.lexer_next_token();
    assert(token2.type == TokenType.INVALID_TOKEN);

    // Test incomplete hex escape
    String source3 = "\"\\x\"";
    Lexer lexer3;
    lexer3.init(source3);

    Token token3 = lexer3.lexer_next_token();
    assert(token3.type == TokenType.INVALID_TOKEN);

    // Test incomplete unicode escape
    String source4 = "\"\\u123\"";
    Lexer lexer4;
    lexer4.init(source4);

    Token token4 = lexer4.lexer_next_token();
    assert(token4.type == TokenType.INVALID_TOKEN);
}

fn void test_hash_identifiers()
{
    String source = "#macro #define #include # #_test #Test_Case";
    Lexer lexer;
    lexer.init(source);

    // #macro
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.HASH_IDENT);
    assert(token1.lexeme == "#macro");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // #define
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.HASH_IDENT);
    assert(token3.lexeme == "#define");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // #include
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.HASH_IDENT);
    assert(token5.lexeme == "#include");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // # (standalone hash symbol)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.HASH);
    assert(token7.lexeme == "#");

    // whitespace
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.WHITESPACE);

    // #_test (identifier starting with underscore)
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.HASH_IDENT);
    assert(token9.lexeme == "#_test");

    // whitespace
    Token token10 = lexer.lexer_next_token();
    assert(token10.type == TokenType.WHITESPACE);

    // #Test_Case (mixed case identifier)
    Token token11 = lexer.lexer_next_token();
    assert(token11.type == TokenType.HASH_IDENT);
    assert(token11.lexeme == "#Test_Case");
}

fn void test_hash_identifier_edge_cases()
{
    String source = "#123 #_ #__";
    Lexer lexer;
    lexer.init(source);

    // #123 (invalid - starts with digit)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.INVALID_TOKEN);

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // #_ (invalid - only underscore)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.INVALID_TOKEN);

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // #__ (invalid - only underscores)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.INVALID_TOKEN);
}

fn void test_hash_vs_at_identifiers()
{
    String source = "#macro @macro #DEFINE @DEFINE";
    Lexer lexer;
    lexer.init(source);

    // #macro (hash identifier)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.HASH_IDENT);
    assert(token1.lexeme == "#macro");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // @macro (at identifier - normal)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.AT_IDENT);
    assert(token3.lexeme == "@macro");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // #DEFINE (hash identifier - no case distinction)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.HASH_IDENT);
    assert(token5.lexeme == "#DEFINE");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // @DEFINE (at identifier - const)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.AT_CONST_IDENT);
    assert(token7.lexeme == "@DEFINE");
}

fn void test_dollar_identifiers()
{
    String source = "$macro $MACRO $Macro $ $test $Test_Case";
    Lexer lexer;
    lexer.init(source);

    // $macro (compile-time identifier)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.CT_IDENT);
    assert(token1.lexeme == "$macro");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // $MACRO (compile-time const identifier)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.CT_CONST_IDENT);
    assert(token3.lexeme == "$MACRO");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // $Macro (compile-time type identifier)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.CT_TYPE_IDENT);
    assert(token5.lexeme == "$Macro");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // $ (standalone dollar symbol)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.DOLLAR);
    assert(token7.lexeme == "$");

    // whitespace
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.WHITESPACE);

    // $test (compile-time identifier)
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.CT_IDENT);
    assert(token9.lexeme == "$test");

    // whitespace
    Token token10 = lexer.lexer_next_token();
    assert(token10.type == TokenType.WHITESPACE);

    // $Test_Case (compile-time type identifier)
    Token token11 = lexer.lexer_next_token();
    assert(token11.type == TokenType.CT_TYPE_IDENT);
    assert(token11.lexeme == "$Test_Case");
}

fn void test_builtin_tokens()
{
    String source = "$$builtin $$eval $$Type";
    Lexer lexer;
    lexer.init(source);

    // $$builtin
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.BUILTIN);
    assert(token1.lexeme == "$$builtin");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // $$eval
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.BUILTIN);
    assert(token3.lexeme == "$$eval");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // $$Type
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.BUILTIN);
    assert(token5.lexeme == "$$Type");
}

fn void test_dollar_edge_cases()
{
    String source = "$123 $_ $__ $$123 $$";
    Lexer lexer;
    lexer.init(source);

    // $123 (invalid - starts with digit)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.INVALID_TOKEN);

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // $_ (invalid - only underscore)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.INVALID_TOKEN);

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // $__ (invalid - only underscores)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.INVALID_TOKEN);

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // $$123 (invalid - $$ not followed by letter)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.INVALID_TOKEN);

    // whitespace
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.WHITESPACE);

    // $$ (invalid - $$ not followed by identifier)
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.INVALID_TOKEN);
}

fn void test_vector_brackets()
{
    String source = "[< >] [ ] [<>]";
    Lexer lexer;
    lexer.init(source);

    // [< (left vector bracket)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.LVEC);
    assert(token1.lexeme == "[<");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // >] (right vector bracket)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.RVEC);
    assert(token3.lexeme == ">]");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // [ (regular left bracket)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.LBRACKET);
    assert(token5.lexeme == "[");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // ] (regular right bracket)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.RBRACKET);
    assert(token7.lexeme == "]");

    // whitespace
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.WHITESPACE);

    // [< (left vector bracket)
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.LVEC);
    assert(token9.lexeme == "[<");

    // >] (right vector bracket)
    Token token10 = lexer.lexer_next_token();
    assert(token10.type == TokenType.RVEC);
    assert(token10.lexeme == ">]");
}

fn void test_vector_vs_comparison()
{
    String source = "[<5] [< 5]";
    Lexer lexer;
    lexer.init(source);

    // [< (vector bracket)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.LVEC);
    assert(token1.lexeme == "[<");

    // 5 (number)
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.INTEGER);
    assert(token2.lexeme == "5");

    // ] (right bracket)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.RBRACKET);

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // [< (vector bracket)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.LVEC);
    assert(token5.lexeme == "[<");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // 5 (number)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.INTEGER);
    assert(token7.lexeme == "5");

    // ] (right bracket)
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.RBRACKET);
}

fn void test_bracket_combinations()
{
    String source = "[[< [<< [<]";
    Lexer lexer;
    lexer.init(source);

    // [ (regular bracket)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.LBRACKET);
    assert(token1.lexeme == "[");

    // [< (vector bracket)
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.LVEC);
    assert(token2.lexeme == "[<");

    // whitespace
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.WHITESPACE);

    // [< (vector bracket)
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.LVEC);
    assert(token4.lexeme == "[<");

    // < (less than)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.LESS);
    assert(token5.lexeme == "<");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // [< (vector bracket)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.LVEC);
    assert(token7.lexeme == "[<");

    // ] (right bracket)
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.RBRACKET);
    assert(token8.lexeme == "]");
}

fn void test_vector_bracket_combinations()
{
    String source = ">] >> >]> [<>] ><";
    Lexer lexer;
    lexer.init(source);

    // >] (right vector bracket)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.RVEC);
    assert(token1.lexeme == ">]");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // >> (right shift)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.SHR);
    assert(token3.lexeme == ">>");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // >]> (right vector bracket followed by greater)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.RVEC);
    assert(token5.lexeme == ">]");

    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.GREATER);
    assert(token6.lexeme == ">");

    // whitespace
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.WHITESPACE);

    // [<>] (left vector bracket followed by right vector bracket)
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.LVEC);
    assert(token8.lexeme == "[<");

    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.RVEC);
    assert(token9.lexeme == ">]");

    // whitespace
    Token token10 = lexer.lexer_next_token();
    assert(token10.type == TokenType.WHITESPACE);

    // >< (greater followed by less)
    Token token11 = lexer.lexer_next_token();
    assert(token11.type == TokenType.GREATER);
    assert(token11.lexeme == ">");

    Token token12 = lexer.lexer_next_token();
    assert(token12.type == TokenType.LESS);
    assert(token12.lexeme == "<");
}

fn void test_ampersand_tokens()
{
    String source = "& && &&& &= &&&&";
    Lexer lexer;
    lexer.init(source);

    // & (ampersand)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.AMPERSAND);
    assert(token1.lexeme == "&");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // && (logical and)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.AND);
    assert(token3.lexeme == "&&");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // &&& (compile-time and)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.CT_AND);
    assert(token5.lexeme == "&&&");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // &= (bitwise and assign)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.BIT_AND_ASSIGN);
    assert(token7.lexeme == "&=");

    // whitespace
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.WHITESPACE);

    // &&&& (compile-time and followed by ampersand)
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.CT_AND);
    assert(token9.lexeme == "&&&");

    Token token10 = lexer.lexer_next_token();
    assert(token10.type == TokenType.AMPERSAND);
    assert(token10.lexeme == "&");
}

fn void test_ampersand_precedence()
{
    String source = "&&&= &&&& &&&&=";
    Lexer lexer;
    lexer.init(source);

    // &&&= (compile-time and followed by equals)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.CT_AND);
    assert(token1.lexeme == "&&&");

    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.EQUAL);
    assert(token2.lexeme == "=");

    // whitespace
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.WHITESPACE);

    // &&&& (compile-time and followed by ampersand)
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.CT_AND);
    assert(token4.lexeme == "&&&");

    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.AMPERSAND);
    assert(token5.lexeme == "&");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // &&&&= (compile-time and followed by bitwise and assign)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.CT_AND);
    assert(token7.lexeme == "&&&");

    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.BIT_AND_ASSIGN);
    assert(token8.lexeme == "&=");
}

fn void test_pipe_tokens()
{
    String source = "| || ||| |= ||||";
    Lexer lexer;
    lexer.init(source);

    // | (pipe)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.PIPE);
    assert(token1.lexeme == "|");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // || (logical or)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.OR);
    assert(token3.lexeme == "||");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // ||| (compile-time or)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.CT_OR);
    assert(token5.lexeme == "|||");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // |= (bitwise or assign)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.BIT_OR_ASSIGN);
    assert(token7.lexeme == "|=");

    // whitespace
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.WHITESPACE);

    // |||| (compile-time or followed by pipe)
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.CT_OR);
    assert(token9.lexeme == "|||");

    Token token10 = lexer.lexer_next_token();
    assert(token10.type == TokenType.PIPE);
    assert(token10.lexeme == "|");
}

fn void test_pipe_precedence()
{
    String source = "|||= |||| ||||=";
    Lexer lexer;
    lexer.init(source);

    // |||= (compile-time or followed by equals)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.CT_OR);
    assert(token1.lexeme == "|||");

    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.EQUAL);
    assert(token2.lexeme == "=");

    // whitespace
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.WHITESPACE);

    // |||| (compile-time or followed by pipe)
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.CT_OR);
    assert(token4.lexeme == "|||");

    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.PIPE);
    assert(token5.lexeme == "|");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // ||||= (compile-time or followed by bitwise or assign)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.CT_OR);
    assert(token7.lexeme == "|||");

    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.BIT_OR_ASSIGN);
    assert(token8.lexeme == "|=");
}

fn void test_logical_operators()
{
    String source = "&& &&& || |||";
    Lexer lexer;
    lexer.init(source);

    // && (logical and)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.AND);
    assert(token1.lexeme == "&&");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // &&& (compile-time and)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.CT_AND);
    assert(token3.lexeme == "&&&");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // || (logical or)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.OR);
    assert(token5.lexeme == "||");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // ||| (compile-time or)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.CT_OR);
    assert(token7.lexeme == "|||");
}

fn void test_plus_precedence()
{
    String source = "+++= ++++ +++++=";
    Lexer lexer;
    lexer.init(source);

    // +++= (compile-time concat followed by equals)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.CT_CONCAT);
    assert(token1.lexeme == "+++");

    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.EQUAL);
    assert(token2.lexeme == "=");

    // whitespace
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.WHITESPACE);

    // ++++ (compile-time concat followed by plus)
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.CT_CONCAT);
    assert(token4.lexeme == "+++");

    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.PLUS);
    assert(token5.lexeme == "+");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // +++++= (compile-time concat followed by increment followed by equals)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.CT_CONCAT);
    assert(token7.lexeme == "+++");

    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.PLUSPLUS);
    assert(token8.lexeme == "++");

    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.EQUAL);
    assert(token9.lexeme == "=");
}

fn void test_bangbang_tokens()
{
    String source = "! != !! !!!";
    Lexer lexer;
    lexer.init(source);

    // ! (bang)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.BANG);
    assert(token1.lexeme == "!");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // != (not equal)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.NOT_EQUAL);
    assert(token3.lexeme == "!=");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // !! (bangbang)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.BANGBANG);
    assert(token5.lexeme == "!!");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // !!! (bangbang followed by bang)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.BANGBANG);
    assert(token7.lexeme == "!!");

    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.BANG);
    assert(token8.lexeme == "!");
}

fn void test_bangbang_precedence()
{
    String source = "!!= !!!=";
    Lexer lexer;
    lexer.init(source);

    // !!= (bangbang followed by equals)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.BANGBANG);
    assert(token1.lexeme == "!!");

    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.EQUAL);
    assert(token2.lexeme == "=");

    // whitespace
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.WHITESPACE);

    // !!!= (bangbang followed by not-equal)
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.BANGBANG);
    assert(token4.lexeme == "!!");

    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.NOT_EQUAL);
    assert(token5.lexeme == "!=");
}

fn void test_bang_combinations()
{
    String source = "!a !=b !!c";
    Lexer lexer;
    lexer.init(source);

    // ! (bang)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.BANG);
    assert(token1.lexeme == "!");

    // a (identifier)
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.IDENT);
    assert(token2.lexeme == "a");

    // whitespace
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.WHITESPACE);

    // != (not equal)
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.NOT_EQUAL);
    assert(token4.lexeme == "!=");

    // b (identifier)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.IDENT);
    assert(token5.lexeme == "b");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // !! (bangbang)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.BANGBANG);
    assert(token7.lexeme == "!!");

    // c (identifier)
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.IDENT);
    assert(token8.lexeme == "c");
}

fn void test_hex_arrays()
{
    String source = "x\"4865 6c6c 6f20 776f 726c 6421\" x'deadbeef' x`cafe babe`";
    Lexer lexer;
    lexer.init(source);

    // x"4865 6c6c 6f20 776f 726c 6421" (Hello World!)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.HEX_ARRAY);
    assert(token1.lexeme == "x\"4865 6c6c 6f20 776f 726c 6421\"");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // x'deadbeef'
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.HEX_ARRAY);
    assert(token3.lexeme == "x'deadbeef'");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // x`cafe babe`
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.HEX_ARRAY);
    assert(token5.lexeme == "x`cafe babe`");
}

fn void test_hex_array_errors()
{
    // Test that x123 is a valid identifier, not a hex array
    String source1 = "x123";
    Lexer lexer1;
    lexer1.init(source1);

    Token token1 = lexer1.lexer_next_token();
    assert(token1.type == TokenType.IDENT);
    assert(token1.lexeme == "x123");

    // Test invalid hex array - invalid character
    String source2 = "x\"hello\"";
    Lexer lexer2;
    lexer2.init(source2);

    Token token2 = lexer2.lexer_next_token();
    assert(token2.type == TokenType.INVALID_TOKEN);

    // Test unterminated hex array
    String source3 = "x\"deadbeef";
    Lexer lexer3;
    lexer3.init(source3);

    Token token3 = lexer3.lexer_next_token();
    assert(token3.type == TokenType.INVALID_TOKEN);
}

fn void test_base64_arrays()
{
    String source = "b64\"SGVsbG8gV29ybGQh\" b64'aGVsbG8=' b64`d29ybGQ=`";
    Lexer lexer;
    lexer.init(source);

    // b64"SGVsbG8gV29ybGQh" (Hello World!)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.BASE64_ARRAY);
    assert(token1.lexeme == "b64\"SGVsbG8gV29ybGQh\"");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // b64'aGVsbG8='
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.BASE64_ARRAY);
    assert(token3.lexeme == "b64'aGVsbG8='");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // b64`d29ybGQ=`
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.BASE64_ARRAY);
    assert(token5.lexeme == "b64`d29ybGQ=`");
}

fn void test_base64_with_whitespace()
{
    String source = "b64\"SGVs bG8g V29y bGQh\"";
    Lexer lexer;
    lexer.init(source);

    Token token = lexer.lexer_next_token();
    assert(token.type == TokenType.BASE64_ARRAY);
    assert(token.lexeme == "b64\"SGVs bG8g V29y bGQh\"");
}

fn void test_base64_errors()
{
    // Test that b123 is a valid identifier, not a base64 array
    String source1 = "b123";
    Lexer lexer1;
    lexer1.init(source1);

    Token token1 = lexer1.lexer_next_token();
    assert(token1.type == TokenType.IDENT);
    assert(token1.lexeme == "b123");

    // Test invalid base64 array - invalid character
    String source2 = "b64\"hello@world\"";
    Lexer lexer2;
    lexer2.init(source2);

    Token token2 = lexer2.lexer_next_token();
    assert(token2.type == TokenType.INVALID_TOKEN);

    // Test unterminated base64 array
    String source3 = "b64\"SGVsbG8=";
    Lexer lexer3;
    lexer3.init(source3);

    Token token3 = lexer3.lexer_next_token();
    assert(token3.type == TokenType.INVALID_TOKEN);

    // Test incomplete b64 prefix
    String source4 = "b6\"test\"";
    Lexer lexer4;
    lexer4.init(source4);

    Token token4 = lexer4.lexer_next_token();
    assert(token4.type == TokenType.IDENT);
    assert(token4.lexeme == "b6");
}

fn void test_decimal_numbers()
{
    String source = "123 456_789 0 42";
    Lexer lexer;
    lexer.init(source);

    // 123
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.INTEGER);
    assert(token1.lexeme == "123");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // 456_789
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.INTEGER);
    assert(token3.lexeme == "456_789");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // 0
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.INTEGER);
    assert(token5.lexeme == "0");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // 42
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.INTEGER);
    assert(token7.lexeme == "42");
}

fn void test_float_numbers()
{
    String source = "3.14 123.456_789 42. 1e10 2.5e-3";
    Lexer lexer;
    lexer.init(source);

    // 3.14
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.REAL);
    assert(token1.lexeme == "3.14");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // 123.456_789
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.REAL);
    assert(token3.lexeme == "123.456_789");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // 42.
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.REAL);
    assert(token5.lexeme == "42.");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // 1e10
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.REAL);
    assert(token7.lexeme == "1e10");

    // whitespace
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.WHITESPACE);

    // 2.5e-3
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.REAL);
    assert(token9.lexeme == "2.5e-3");
}

fn void test_hex_numbers()
{
    String source = "0x123 0xFF 0xDEAD_BEEF";
    Lexer lexer;
    lexer.init(source);

    // 0x123
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.INTEGER);
    assert(token1.lexeme == "0x123");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // 0xFF
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.INTEGER);
    assert(token3.lexeme == "0xFF");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // 0xDEAD_BEEF
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.INTEGER);
    assert(token5.lexeme == "0xDEAD_BEEF");
}

fn void test_hex_float_numbers()
{
    String source = "0x1.23p4 0xABC.DEFp-2 0x123f32";
    Lexer lexer;
    lexer.init(source);

    // 0x1.23p4 (hex float with exponent)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.REAL);
    assert(token1.lexeme == "0x1.23p4");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // 0xABC.DEFp-2 (hex float with negative exponent)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.REAL);
    assert(token3.lexeme == "0xABC.DEFp-2");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // 0x123f32 (hex integer - f32 are all valid hex digits)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.INTEGER);
    assert(token5.lexeme == "0x123f32");
}

fn void test_octal_binary_numbers()
{
    String source = "0o777 0b1010_1100";
    Lexer lexer;
    lexer.init(source);

    // 0o777
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.INTEGER);
    assert(token1.lexeme == "0o777");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // 0b1010_1100
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.INTEGER);
    assert(token3.lexeme == "0b1010_1100");
}

fn void test_number_errors()
{
    // Test invalid hex number
    String source1 = "0x";
    Lexer lexer1;
    lexer1.init(source1);

    Token token1 = lexer1.lexer_next_token();
    assert(token1.type == TokenType.INVALID_TOKEN);

    // Test invalid octal number
    String source2 = "0o";
    Lexer lexer2;
    lexer2.init(source2);

    Token token2 = lexer2.lexer_next_token();
    assert(token2.type == TokenType.INVALID_TOKEN);

    // Test invalid binary number
    String source3 = "0b";
    Lexer lexer3;
    lexer3.init(source3);

    Token token3 = lexer3.lexer_next_token();
    assert(token3.type == TokenType.INVALID_TOKEN);

    // Test multiple underscores
    String source4 = "123__456";
    Lexer lexer4;
    lexer4.init(source4);

    Token token4 = lexer4.lexer_next_token();
    assert(token4.type == TokenType.INVALID_TOKEN);
}

fn void test_number_suffixes()
{
    String source = "42i32 123u64 3.14f32 2.5f64 100u8 -1i8";
    Lexer lexer;
    lexer.init(source);

    // 42i32
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.INTEGER);
    assert(token1.lexeme == "42i32");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // 123u64
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.INTEGER);
    assert(token3.lexeme == "123u64");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // 3.14f32
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.REAL);
    assert(token5.lexeme == "3.14f32");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // 2.5f64
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.REAL);
    assert(token7.lexeme == "2.5f64");

    // whitespace
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.WHITESPACE);

    // 100u8
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.INTEGER);
    assert(token9.lexeme == "100u8");

    // whitespace
    Token token10 = lexer.lexer_next_token();
    assert(token10.type == TokenType.WHITESPACE);

    // - (minus operator)
    Token token11 = lexer.lexer_next_token();
    assert(token11.type == TokenType.MINUS);

    // 1i8
    Token token12 = lexer.lexer_next_token();
    assert(token12.type == TokenType.INTEGER);
    assert(token12.lexeme == "1i8");
}

fn void test_legacy_number_suffixes()
{
    String source = "42L 123UL 456LL 789ULL 3.14f 2.5d";
    Lexer lexer;
    lexer.init(source);

    // 42L
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.INTEGER);
    assert(token1.lexeme == "42L");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // 123UL
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.INTEGER);
    assert(token3.lexeme == "123UL");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // 456LL
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.INTEGER);
    assert(token5.lexeme == "456LL");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // 789ULL
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.INTEGER);
    assert(token7.lexeme == "789ULL");

    // whitespace
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.WHITESPACE);

    // 3.14f
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.REAL);
    assert(token9.lexeme == "3.14f");

    // whitespace
    Token token10 = lexer.lexer_next_token();
    assert(token10.type == TokenType.WHITESPACE);

    // 2.5d
    Token token11 = lexer.lexer_next_token();
    assert(token11.type == TokenType.REAL);
    assert(token11.lexeme == "2.5d");
}

fn void test_number_suffix_errors()
{
    // Test invalid suffix on float
    String source1 = "3.14i32";
    Lexer lexer1;
    lexer1.init(source1);

    Token token1 = lexer1.lexer_next_token();
    assert(token1.type == TokenType.INVALID_TOKEN);

    // Test 'i' without bit width
    String source2 = "42i";
    Lexer lexer2;
    lexer2.init(source2);

    Token token2 = lexer2.lexer_next_token();
    assert(token2.type == TokenType.INVALID_TOKEN);

    // Test hex number that looks like it has a suffix but doesn't
    String source3 = "0x123f32";
    Lexer lexer3;
    lexer3.init(source3);

    Token token3 = lexer3.lexer_next_token();
    assert(token3.type == TokenType.INTEGER); // f32 are valid hex digits
    assert(token3.lexeme == "0x123f32");
}

fn void test_hex_with_real_suffixes()
{
    String source = "0x123u64 0xABCi32 0x456L";
    Lexer lexer;
    lexer.init(source);

    // 0x123u64 (hex with unsigned suffix)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.INTEGER);
    assert(token1.lexeme == "0x123u64");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // 0xABCi32 (hex with signed suffix)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.INTEGER);
    assert(token3.lexeme == "0xABCi32");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // 0x456L (hex with long suffix)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.INTEGER);
    assert(token5.lexeme == "0x456L");
}

fn void test_implies_tokens()
{
    String source = "= == => =>";
    Lexer lexer;
    lexer.init(source);

    // = (equals)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.EQUAL);
    assert(token1.lexeme == "=");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // == (double equals)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.EQEQ);
    assert(token3.lexeme == "==");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // => (implies)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.IMPLIES);
    assert(token5.lexeme == "=>");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // => (another implies)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.IMPLIES);
    assert(token7.lexeme == "=>");
}

fn void test_implies_vs_arrow()
{
    String source = "=> -> ==> ->=";
    Lexer lexer;
    lexer.init(source);

    // => (implies)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.IMPLIES);
    assert(token1.lexeme == "=>");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // -> (arrow)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.ARROW);
    assert(token3.lexeme == "->");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // ==> (equals followed by implies)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.EQEQ);
    assert(token5.lexeme == "==");

    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.GREATER);
    assert(token6.lexeme == ">");

    // whitespace
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.WHITESPACE);

    // ->= (arrow followed by equals)
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.ARROW);
    assert(token8.lexeme == "->");

    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.EQUAL);
    assert(token9.lexeme == "=");
}

fn void test_equal_family_tokens()
{
    String source = "= == => === =>=";
    Lexer lexer;
    lexer.init(source);

    // = (equals)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.EQUAL);
    assert(token1.lexeme == "=");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // == (double equals)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.EQEQ);
    assert(token3.lexeme == "==");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // => (implies)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.IMPLIES);
    assert(token5.lexeme == "=>");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // === (double equals followed by equals)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.EQEQ);
    assert(token7.lexeme == "==");

    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.EQUAL);
    assert(token8.lexeme == "=");

    // whitespace
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.WHITESPACE);

    // =>= (implies followed by equals)
    Token token10 = lexer.lexer_next_token();
    assert(token10.type == TokenType.IMPLIES);
    assert(token10.lexeme == "=>");

    Token token11 = lexer.lexer_next_token();
    assert(token11.type == TokenType.EQUAL);
    assert(token11.lexeme == "=");
}

fn void test_question_tokens()
{
    String source = "? ?? ?: ???";
    Lexer lexer;
    lexer.init(source);

    // ? (question)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.QUESTION);
    assert(token1.lexeme == "?");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // ?? (questquest/null coalescing)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.QUESTQUEST);
    assert(token3.lexeme == "??");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // ?: (elvis)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.ELVIS);
    assert(token5.lexeme == "?:");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // ??? (questquest followed by question)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.QUESTQUEST);
    assert(token7.lexeme == "??");

    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.QUESTION);
    assert(token8.lexeme == "?");
}

fn void test_question_precedence()
{
    String source = "??= ?:= ??:";
    Lexer lexer;
    lexer.init(source);

    // ??= (questquest followed by equals)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.QUESTQUEST);
    assert(token1.lexeme == "??");

    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.EQUAL);
    assert(token2.lexeme == "=");

    // whitespace
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.WHITESPACE);

    // ?:= (elvis followed by equals)
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.ELVIS);
    assert(token4.lexeme == "?:");

    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.EQUAL);
    assert(token5.lexeme == "=");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // ??: (questquest followed by colon)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.QUESTQUEST);
    assert(token7.lexeme == "??");

    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.COLON);
    assert(token8.lexeme == ":");
}

fn void test_ternary_vs_elvis()
{
    String source = "a ? b : c a ?: b";
    Lexer lexer;
    lexer.init(source);

    // a (identifier)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.IDENT);
    assert(token1.lexeme == "a");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // ? (question for ternary)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.QUESTION);
    assert(token3.lexeme == "?");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // b (identifier)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.IDENT);
    assert(token5.lexeme == "b");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // : (colon for ternary)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.COLON);
    assert(token7.lexeme == ":");

    // whitespace
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.WHITESPACE);

    // c (identifier)
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.IDENT);
    assert(token9.lexeme == "c");

    // whitespace
    Token token10 = lexer.lexer_next_token();
    assert(token10.type == TokenType.WHITESPACE);

    // a (identifier)
    Token token11 = lexer.lexer_next_token();
    assert(token11.type == TokenType.IDENT);
    assert(token11.lexeme == "a");

    // whitespace
    Token token12 = lexer.lexer_next_token();
    assert(token12.type == TokenType.WHITESPACE);

    // ?: (elvis operator)
    Token token13 = lexer.lexer_next_token();
    assert(token13.type == TokenType.ELVIS);
    assert(token13.lexeme == "?:");

    // whitespace
    Token token14 = lexer.lexer_next_token();
    assert(token14.type == TokenType.WHITESPACE);

    // b (identifier)
    Token token15 = lexer.lexer_next_token();
    assert(token15.type == TokenType.IDENT);
    assert(token15.lexeme == "b");
}

fn void test_doc_comments()
{
    String source = "<* Simple doc comment *> <*Multi\nline\ndoc*>";
    Lexer lexer;
    lexer.init(source);

    // <* Simple doc comment *>
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.DOC_COMMENT);
    assert(token1.lexeme == "<* Simple doc comment *>");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // <*Multi\nline\ndoc*> (multiline doc comment)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.DOC_COMMENT);
    assert(token3.lexeme == "<*Multi\nline\ndoc*>");
}

fn void test_doc_comment_vs_less_star()
{
    String source = "< * <* doc *> << <*another*>";
    Lexer lexer;
    lexer.init(source);

    // < (less than)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.LESS);
    assert(token1.lexeme == "<");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // * (star)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.STAR);
    assert(token3.lexeme == "*");

    // whitespace
    Token token4 = lexer.lexer_next_token();
    assert(token4.type == TokenType.WHITESPACE);

    // <* doc *> (doc comment)
    Token token5 = lexer.lexer_next_token();
    assert(token5.type == TokenType.DOC_COMMENT);
    assert(token5.lexeme == "<* doc *>");

    // whitespace
    Token token6 = lexer.lexer_next_token();
    assert(token6.type == TokenType.WHITESPACE);

    // << (left shift)
    Token token7 = lexer.lexer_next_token();
    assert(token7.type == TokenType.SHL);
    assert(token7.lexeme == "<<");

    // whitespace
    Token token8 = lexer.lexer_next_token();
    assert(token8.type == TokenType.WHITESPACE);

    // <*another*> (another doc comment)
    Token token9 = lexer.lexer_next_token();
    assert(token9.type == TokenType.DOC_COMMENT);
    assert(token9.lexeme == "<*another*>");
}

fn void test_doc_comment_special_content()
{
    String source = "<* @param x The value\n * @return Result *> <* /* nested */ comment *>";
    Lexer lexer;
    lexer.init(source);

    // <* @param x The value\n * @return Result *> (doc with special content)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.DOC_COMMENT);
    assert(token1.lexeme == "<* @param x The value\n * @return Result *>");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // <* /* nested */ comment *> (doc with nested comment-like content)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.DOC_COMMENT);
    assert(token3.lexeme == "<* /* nested */ comment *>");
}

fn void test_doc_comment_errors()
{
    String source = "<* unterminated doc comment";
    Lexer lexer;
    lexer.init(source);

    // <* unterminated doc comment (no closing *>)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.INVALID_TOKEN);
}

fn void test_doc_comment_empty()
{
    String source = "<**> <* *>";
    Lexer lexer;
    lexer.init(source);

    // <**> (empty doc comment)
    Token token1 = lexer.lexer_next_token();
    assert(token1.type == TokenType.DOC_COMMENT);
    assert(token1.lexeme == "<**>");

    // whitespace
    Token token2 = lexer.lexer_next_token();
    assert(token2.type == TokenType.WHITESPACE);

    // <* *> (doc comment with just space)
    Token token3 = lexer.lexer_next_token();
    assert(token3.type == TokenType.DOC_COMMENT);
    assert(token3.lexeme == "<* *>");
}
