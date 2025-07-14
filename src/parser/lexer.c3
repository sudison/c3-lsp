// Copyright (c) 2024 C3 Project. All rights reserved.
// Use of this source code is governed by the GNU LGPLv3.0 license
// a copy of which can be found in the LICENSE file.

module parser;

/**
 * Lexer state for tokenizing C3 source code
 */
struct Lexer
{
    String source;             // Source code text
    usz current;               // Current position index in source
    usz lexing_start;          // Start index of current token
    uint file_id;              // File identifier
    Token current_token;       // Current token
    bool has_token;            // Whether current_token is valid
}

/**
 * Initialize lexer with source code
 */
fn void Lexer.init(&self, String source, uint file_id = 0)
{
    *self = {
        .source = source,
        .current = 0,
        .lexing_start = 0,
        .file_id = file_id,
        .has_token = false
    };
}

/**
 * Peek at current character without advancing
 */
fn char Lexer.peek(&self) @inline
{
    if (self.current >= self.source.len) return '\0';
    return self.source[self.current];
}

/**
 * Peek at next character without advancing
 */
fn char Lexer.peek_next(&self) @inline
{
    if (self.current + 1 >= self.source.len) return '\0';
    return self.source[self.current + 1];
}

/**
 * Check if we've reached end of input
 */
fn bool Lexer.reached_end(&self) @inline
{
    return self.current >= self.source.len;
}

/**
 * Advance to next character and return it
 */
fn char Lexer.next(&self)
{
    self.current++;
    return self.peek();
}

/**
 * Move back one character
 */
fn void Lexer.backtrack(&self)
{
    if (self.current > 0)
    {
        self.current--;
    }
}

/**
 * Skip n characters
 */
fn void Lexer.skip(&self, int steps)
{
    for (int i = 0; i < steps; i++)
    {
        self.next();
    }
}

/**
 * Match a character and advance if it matches
 */
fn bool Lexer.match(&self, char expected)
{
    if (self.peek() != expected) return false;
    self.next();
    return true;
}

/**
 * Start lexing a new token
 */
fn void Lexer.begin_new_token(&self) @private
{
    self.lexing_start = self.current;
}

/**
 * Create a token with the given type
 */
fn Token Lexer.make_token(&self, TokenType type) @private
{
    usz length = self.current - self.lexing_start;

    String lexeme;
    if (length == 0)
    {
        lexeme = "";
    }
    else
    {
        lexeme = self.source[self.lexing_start..self.current - 1];
    }

    return {
        .type = type,
        .span = {
            .file_id = self.file_id,
            .start = (uint)self.lexing_start,
            .end = (uint)self.current
        },
        .lexeme = lexeme
    };
}

/**
 * Create an error token with the given message
 */
fn Token Lexer.make_error_token(&self, String message) @private
{
    usz length = self.current - self.lexing_start;

    String lexeme;
    if (length == 0)
    {
        lexeme = "";
    }
    else
    {
        lexeme = self.source[self.lexing_start..self.current - 1];
    }

    return {
        .type = TokenType.INVALID_TOKEN,
        .span = {
            .file_id = self.file_id,
            .start = (uint)self.lexing_start,
            .end = (uint)self.current
        },
        .lexeme = lexeme
    };
}

/**
 * Scan a single character token
 */
fn Token Lexer.scan_single_char(&self, TokenType type) @private
{
    self.next();
    return self.make_token(type);
}

/**
 * Scan an identifier starting with a prefix character
 * Based on the original C lexer's scan_ident function
 */
fn Token Lexer.scan_ident(&self, TokenType normal, TokenType const_token, TokenType type_token, char prefix) @private
{
    TokenType type = TokenType.INVALID_TOKEN;
    bool is_invalid = false;

    // Skip the prefix if present
    if (prefix != '\0')
    {
        self.next(); // consume prefix (@, #, $, etc.)
    }

    // Skip leading underscores
    char c;
    while ((c = self.peek()) == '_')
    {
        self.next();
    }

    // Scan the main identifier part
    while (true)
    {
        c = self.peek();
        if (c.is_lower())
        {
            if (type == TokenType.INVALID_TOKEN)
            {
                type = normal;
            }
            else if (type == const_token)
            {
                type = type_token;
            }
        }
        else if (c.is_upper())
        {
            if (type == TokenType.INVALID_TOKEN)
            {
                type = const_token;
            }
        }
        else if (c.is_digit())
        {
            if (type == TokenType.INVALID_TOKEN)
            {
                // Error: A letter must precede any digit
                is_invalid = true;
            }
            // Continue scanning to consume the entire identifier
        }
        else if (c == '_')
        {
            // Continue scanning
        }
        else
        {
            break; // End of identifier
        }

        self.next();
    }

    // Check for valid identifier
    usz length = self.current - self.lexing_start;
    if (is_invalid || type == TokenType.INVALID_TOKEN)
    {
        if (prefix == '\0' && length == 1)
        {
            // Single underscore
            return self.make_token(TokenType.IDENT); // or could be a special UNDERSCORE token
        }
        if (prefix != '\0' && length == 1)
        {
            // Error: identifier expected after prefix
            return self.make_token(TokenType.INVALID_TOKEN);
        }
        // Error: identifier may not consist of only '_' characters or starts with digit
        return self.make_token(TokenType.INVALID_TOKEN);
    }

    return self.make_token(type);
}

/**
 * Main token scanning function
 * Returns the next token from the input
 */
fn Token Lexer.lexer_next_token(&self)
{
    // Start new token
    self.begin_new_token();
    
    // Check for end of file
    if (self.reached_end())
    {
        return self.make_token(TokenType.EOF);
    }
    
    char c = self.peek();

    // Follow the C lexer pattern with specific character cases first
    switch (c)
    {
        case ' ':
        case '\t':
            return self.scan_whitespace();

        case '\n':
            return self.scan_newline();

        case ',':
            return self.scan_single_char(TokenType.COMMA);
        case ';':
            return self.scan_single_char(TokenType.SEMICOLON);
        case '{':
            return self.scan_single_char(TokenType.LBRACE);
        case '}':
            return self.scan_single_char(TokenType.RBRACE);
        case '(':
            return self.scan_single_char(TokenType.LPAREN);
        case ')':
            return self.scan_single_char(TokenType.RPAREN);
        case '[':
            return self.scan_lbracket();
        case ']':
            return self.scan_single_char(TokenType.RBRACKET);
        case '~':
            return self.scan_single_char(TokenType.TILDE);
        case '@':
            return self.scan_at();
        case '#':
            return self.scan_hash();
        case '$':
            return self.scan_dollar();
        case '?':
            return self.scan_question();
        case '\'':
            return self.scan_char();
        case '`':
            return self.scan_raw_string();
        case '"':
            return self.scan_string();
        case '.':
            return self.scan_dot();
        case ':':
            return self.scan_colon();
        case '=':
            return self.scan_equal();
        case '!':
            return self.scan_bang();
        case '<':
            return self.scan_less();
        case '>':
            return self.scan_greater();
        case '+':
            return self.scan_plus();
        case '-':
            return self.scan_minus();
        case '*':
            return self.scan_star();
        case '/':
            return self.scan_slash();
        case '%':
            return self.scan_percent();
        case '&':
            return self.scan_ampersand();
        case '|':
            return self.scan_pipe();
        case '^':
            return self.scan_caret();
        case 'b':
            return self.scan_b();
        case 'x':
            return self.scan_x();
        case '_':
            return self.scan_ident(TokenType.IDENT, TokenType.CONST_IDENT, TokenType.TYPE_IDENT, '\0');

        default:
            // Follow C lexer pattern: check digits, then letters, then error
            if (c.is_digit())
            {
                return self.scan_digit();
            }
            if (c.is_alpha())
            {
                return self.scan_ident(TokenType.IDENT, TokenType.CONST_IDENT, TokenType.TYPE_IDENT, '\0');
            }
            // Unknown character
            self.next();
            return self.make_token(TokenType.INVALID_TOKEN);
    }
}

/**
 * Scan whitespace token
 */
fn Token Lexer.scan_whitespace(&self) @private
{
    while (self.peek() == ' ' || self.peek() == '\t')
    {
        self.next();
    }
    return self.make_token(TokenType.WHITESPACE);
}

/**
 * Scan newline token
 */
fn Token Lexer.scan_newline(&self) @private
{
    self.next(); // consume \n
    return self.make_token(TokenType.NEWLINE);
}

/**
 * Scan dot-related tokens (., .., ...)
 */
fn Token Lexer.scan_dot(&self) @private
{
    self.next(); // consume first '.'
    
    if (self.match('.'))
    {
        if (self.match('.'))
        {
            return self.make_token(TokenType.ELLIPSIS); // ...
        }
        return self.make_token(TokenType.DOTDOT); // ..
    }
    return self.make_token(TokenType.DOT); // .
}

/**
 * Scan colon-related tokens (:, ::)
 */
fn Token Lexer.scan_colon(&self) @private
{
    self.next(); // consume first ':'
    
    if (self.match(':'))
    {
        return self.make_token(TokenType.SCOPE); // ::
    }
    return self.make_token(TokenType.COLON); // :
}

/**
 * Scan equal-related tokens (=, ==, =>)
 */
fn Token Lexer.scan_equal(&self) @private
{
    self.next(); // consume first '='

    if (self.match('='))
    {
        return self.make_token(TokenType.EQEQ); // ==
    }
    if (self.match('>'))
    {
        return self.make_token(TokenType.IMPLIES); // =>
    }
    return self.make_token(TokenType.EQUAL); // =
}

/**
 * Scan bang-related tokens (!, !=, !!)
 */
fn Token Lexer.scan_bang(&self) @private
{
    self.next(); // consume '!'

    if (self.match('='))
    {
        return self.make_token(TokenType.NOT_EQUAL); // !=
    }
    if (self.match('!'))
    {
        return self.make_token(TokenType.BANGBANG); // !!
    }
    return self.make_token(TokenType.BANG); // !
}

/**
 * Scan less-related tokens (<, <=, <<, <<=, <*)
 */
fn Token Lexer.scan_less(&self) @private
{
    self.next(); // consume '<'

    if (self.match('='))
    {
        return self.make_token(TokenType.LESS_EQ); // <=
    }
    if (self.match('<'))
    {
        if (self.match('='))
        {
            return self.make_token(TokenType.SHL_ASSIGN); // <<=
        }
        return self.make_token(TokenType.SHL); // <<
    }
    if (self.match('*'))
    {
        return self.scan_doc_comment(); // <*
    }
    return self.make_token(TokenType.LESS); // <
}

/**
 * Scan greater-related tokens (>, >=, >>, >>=, >])
 */
fn Token Lexer.scan_greater(&self) @private
{
    self.next(); // consume '>'

    if (self.match('='))
    {
        return self.make_token(TokenType.GREATER_EQ); // >=
    }
    if (self.match('>'))
    {
        if (self.match('='))
        {
            return self.make_token(TokenType.SHR_ASSIGN); // >>=
        }
        return self.make_token(TokenType.SHR); // >>
    }
    if (self.match(']'))
    {
        return self.make_token(TokenType.RVEC); // >]
    }
    return self.make_token(TokenType.GREATER); // >
}

/**
 * Scan plus-related tokens (+, ++, +++, +=)
 */
fn Token Lexer.scan_plus(&self) @private
{
    self.next(); // consume '+'

    if (self.match('+'))
    {
        if (self.match('+'))
        {
            return self.make_token(TokenType.CT_CONCAT); // +++
        }
        return self.make_token(TokenType.PLUSPLUS); // ++
    }
    if (self.match('='))
    {
        return self.make_token(TokenType.PLUS_ASSIGN); // +=
    }
    return self.make_token(TokenType.PLUS); // +
}

/**
 * Scan minus-related tokens (-, --, -=, ->)
 */
fn Token Lexer.scan_minus(&self) @private
{
    self.next(); // consume '-'

    if (self.match('-'))
    {
        return self.make_token(TokenType.MINUSMINUS); // --
    }
    if (self.match('='))
    {
        return self.make_token(TokenType.MINUS_ASSIGN); // -=
    }
    if (self.match('>'))
    {
        return self.make_token(TokenType.ARROW); // ->
    }
    return self.make_token(TokenType.MINUS); // -
}

/**
 * Scan star-related tokens (*, *=)
 */
fn Token Lexer.scan_star(&self) @private
{
    self.next(); // consume '*'

    if (self.match('='))
    {
        return self.make_token(TokenType.MULT_ASSIGN); // *=
    }
    return self.make_token(TokenType.STAR); // *
}

/**
 * Scan slash-related tokens (/, /=, //, /* */)
 */
fn Token Lexer.scan_slash(&self) @private
{
    self.next(); // consume '/'

    if (self.match('='))
    {
        return self.make_token(TokenType.DIV_ASSIGN); // /=
    }
    if (self.match('/'))
    {
        return self.scan_line_comment(); // //
    }
    if (self.match('*'))
    {
        return self.scan_block_comment(); // /* */
    }
    return self.make_token(TokenType.SLASH); // /
}

/**
 * Scan percent-related tokens (%, %=)
 */
fn Token Lexer.scan_percent(&self) @private
{
    self.next(); // consume '%'

    if (self.match('='))
    {
        return self.make_token(TokenType.MOD_ASSIGN); // %=
    }
    return self.make_token(TokenType.PERCENT); // %
}

/**
 * Scan ampersand-related tokens (&, &&, &&&, &=)
 */
fn Token Lexer.scan_ampersand(&self) @private
{
    self.next(); // consume '&'

    if (self.match('&'))
    {
        if (self.match('&'))
        {
            return self.make_token(TokenType.CT_AND); // &&&
        }
        return self.make_token(TokenType.AND); // &&
    }
    if (self.match('='))
    {
        return self.make_token(TokenType.BIT_AND_ASSIGN); // &=
    }
    return self.make_token(TokenType.AMPERSAND); // &
}

/**
 * Scan pipe-related tokens (|, ||, |||, |=)
 */
fn Token Lexer.scan_pipe(&self) @private
{
    self.next(); // consume '|'

    if (self.match('|'))
    {
        if (self.match('|'))
        {
            return self.make_token(TokenType.CT_OR); // |||
        }
        return self.make_token(TokenType.OR); // ||
    }
    if (self.match('='))
    {
        return self.make_token(TokenType.BIT_OR_ASSIGN); // |=
    }
    return self.make_token(TokenType.PIPE); // |
}

/**
 * Scan caret-related tokens (^, ^=)
 */
fn Token Lexer.scan_caret(&self) @private
{
    self.next(); // consume '^'

    if (self.match('='))
    {
        return self.make_token(TokenType.BIT_XOR_ASSIGN); // ^=
    }
    return self.make_token(TokenType.CARET); // ^
}

/**
 * Scan line comment (//....)
 */
fn Token Lexer.scan_line_comment(&self) @private
{
    // Skip until end of line or end of file
    while (!self.reached_end() && self.peek() != '\n')
    {
        self.next();
    }
    return self.make_token(TokenType.COMMENT_LINE);
}

/**
 * Scan block comment (/* ... */)
 */
fn Token Lexer.scan_block_comment(&self) @private
{
    // Look for closing */
    while (!self.reached_end())
    {
        if (self.peek() == '*' && self.peek_next() == '/')
        {
            self.skip(2); // consume */
            break;
        }
        self.next();
    }
    return self.make_token(TokenType.COMMENT_BLOCK);
}

/**
 * Scan @ tokens (@ or @identifier)
 */
fn Token Lexer.scan_at(&self) @private
{
    char next_char = self.peek_next();
    if (next_char.is_alpha() || next_char == '_' || next_char.is_digit())
    {
        return self.scan_ident(TokenType.AT_IDENT, TokenType.AT_CONST_IDENT, TokenType.AT_TYPE_IDENT, '@');
    }
    return self.scan_single_char(TokenType.AT);
}

/**
 * Scan # tokens (# or #identifier)
 */
fn Token Lexer.scan_hash(&self) @private
{
    char next_char = self.peek_next();
    if (next_char.is_alpha() || next_char == '_' || next_char.is_digit())
    {
        return self.scan_hash_ident();
    }
    return self.scan_single_char(TokenType.HASH);
}

/**
 * Scan a # identifier (#macro, #define, etc.)
 * Unlike @ identifiers, # identifiers have only one type
 */
fn Token Lexer.scan_hash_ident(&self) @private
{
    // Reuse the existing scan_ident function
    // For # identifiers, we use HASH_IDENT for all cases (no case-based classification)
    return self.scan_ident(TokenType.HASH_IDENT, TokenType.HASH_IDENT, TokenType.HASH_IDENT, '#');
}

/**
 * Scan $ tokens ($, $identifier, $$builtin)
 */
fn Token Lexer.scan_dollar(&self) @private
{
    char next_char = self.peek_next();

    // Handle $$ (builtin tokens)
    if (next_char == '$')
    {
        self.next(); // consume first $
        self.next(); // consume second $

        // Check if followed by a letter
        char after_dollar = self.peek();
        if (!after_dollar.is_alpha())
        {
            // Consume any following characters that could be part of an invalid identifier
            while (true)
            {
                char c = self.peek();
                if (c.is_alpha() || c.is_digit() || c == '_')
                {
                    self.next();
                }
                else
                {
                    break;
                }
            }
            return self.make_error_token("Expected identifier after $$");
        }

        // Scan the builtin identifier
        while (true)
        {
            char c = self.peek();
            if (c.is_alpha() || c.is_digit() || c == '_')
            {
                self.next();
            }
            else
            {
                break;
            }
        }

        return self.make_token(TokenType.BUILTIN);
    }

    // Handle $ followed by identifier (compile-time identifiers)
    if (next_char.is_alpha() || next_char == '_' || next_char.is_digit())
    {
        return self.scan_ident(TokenType.CT_IDENT, TokenType.CT_CONST_IDENT, TokenType.CT_TYPE_IDENT, '$');
    }

    // Standalone $
    return self.scan_single_char(TokenType.DOLLAR);
}

/**
 * Scan [ tokens ([ or [<)
 */
fn Token Lexer.scan_lbracket(&self) @private
{
    self.next(); // consume [

    if (self.match('<'))
    {
        return self.make_token(TokenType.LVEC); // [<
    }
    return self.make_token(TokenType.LBRACKET); // [
}

/**
 * Scan ? tokens (?, ??, ?:)
 */
fn Token Lexer.scan_question(&self) @private
{
    self.next(); // consume ?

    if (self.match('?'))
    {
        return self.make_token(TokenType.QUESTQUEST); // ??
    }
    if (self.match(':'))
    {
        return self.make_token(TokenType.ELVIS); // ?:
    }
    return self.make_token(TokenType.QUESTION); // ?
}

/**
 * Scan documentation comment (<* ... *>)
 */
fn Token Lexer.scan_doc_comment(&self) @private
{
    bool found_closing = false;

    // Look for closing *>
    while (!self.reached_end())
    {
        if (self.peek() == '*' && self.peek_next() == '>')
        {
            self.skip(2); // consume *>
            found_closing = true;
            break;
        }
        self.next();
    }

    // Check if we found the closing *>
    if (!found_closing)
    {
        return self.make_error_token("Unterminated documentation comment");
    }

    return self.make_token(TokenType.DOC_COMMENT);
}

/**
 * Check if a character is a valid escape character
 */
fn char get_escape_char(char c) @private
{
    switch (c)
    {
        case 'n': return '\n';
        case 't': return '\t';
        case 'r': return '\r';
        case '\\': return '\\';
        case '\'': return '\'';
        case '"': return '"';
        case '0': return '\0';
        case 'a': return '\a';
        case 'b': return '\b';
        case 'f': return '\f';
        case 'v': return '\v';
        default: return '\0'; // Invalid escape
    }
}

/**
 * Scan a character literal ('c', '\n', etc.)
 */
fn Token Lexer.scan_char(&self) @private
{
    self.next(); // consume opening '

    // Handle empty character literal
    if (self.peek() == '\'')
    {
        self.next(); // consume closing '
        return self.make_error_token("Empty character literal");
    }

    char c = self.peek();

    // Handle end of file
    if (c == '\0')
    {
        return self.make_error_token("Unterminated character literal");
    }

    // Handle newline in character literal
    if (c == '\n')
    {
        return self.make_error_token("Newline in character literal");
    }

    self.next(); // consume the character

    // Handle escape sequences
    if (c == '\\')
    {
        char escape_char = self.peek();
        if (escape_char == '\0')
        {
            return self.make_error_token("Unterminated character literal");
        }

        char escaped = get_escape_char(escape_char);
        if (escaped == '\0' && escape_char != '0')
        {
            // Handle hex escape sequences \xNN
            if (escape_char == 'x')
            {
                self.next(); // consume 'x'
                return self.scan_hex_char_escape();
            }
            // Handle unicode escape sequences \uNNNN and \UNNNNNNNN
            else if (escape_char == 'u' || escape_char == 'U')
            {
                self.next(); // consume 'u' or 'U'
                return self.scan_unicode_char_escape(escape_char == 'U');
            }
            else
            {
                self.next(); // consume the invalid escape char
                return self.make_error_token("Invalid escape sequence");
            }
        }
        else
        {
            self.next(); // consume the escape character
        }
    }

    // Expect closing quote
    if (self.peek() != '\'')
    {
        // Multi-character literal - scan until closing quote or error
        while (!self.reached_end() && self.peek() != '\'' && self.peek() != '\n')
        {
            self.next();
        }
    }

    if (self.peek() != '\'')
    {
        return self.make_error_token("Unterminated character literal");
    }

    self.next(); // consume closing '

    Token token = self.make_token(TokenType.CHAR_LITERAL);
    // Store the character value in the token data
    // For now, we'll just store the lexeme - a full implementation would parse the actual character value
    return token;
}



/**
 * Scan hex escape sequence \xNN
 */
fn Token Lexer.scan_hex_char_escape(&self) @private
{
    // Expect exactly 2 hex digits
    for (int i = 0; i < 2; i++)
    {
        char c = self.peek();
        if (!c.is_xdigit())
        {
            // Consume until closing quote or end
            while (!self.reached_end() && self.peek() != '\'' && self.peek() != '\n')
            {
                self.next();
            }
            if (self.peek() == '\'') self.next(); // consume closing quote if found
            return self.make_error_token("Invalid hex escape sequence");
        }
        self.next();
    }

    // Expect closing quote
    if (self.peek() != '\'')
    {
        return self.make_error_token("Unterminated character literal");
    }

    self.next(); // consume closing '
    return self.make_token(TokenType.CHAR_LITERAL);
}

/**
 * Scan unicode escape sequence \uNNNN or \UNNNNNNNN
 */
fn Token Lexer.scan_unicode_char_escape(&self, bool is_long) @private
{
    int digits = is_long ? 8 : 4;

    // Expect exactly 4 or 8 hex digits
    for (int i = 0; i < digits; i++)
    {
        char c = self.peek();
        if (!c.is_xdigit())
        {
            // Consume until closing quote or end
            while (!self.reached_end() && self.peek() != '\'' && self.peek() != '\n')
            {
                self.next();
            }
            if (self.peek() == '\'') self.next(); // consume closing quote if found
            return self.make_error_token("Invalid unicode escape sequence");
        }
        self.next();
    }

    // Expect closing quote
    if (self.peek() != '\'')
    {
        return self.make_error_token("Unterminated character literal");
    }

    self.next(); // consume closing '
    return self.make_token(TokenType.CHAR_LITERAL);
}

/**
 * Scan a raw string literal (`...`)
 * Raw strings can contain any character including newlines
 * Backticks are escaped by doubling them: ``
 */
fn Token Lexer.scan_raw_string(&self) @private
{
    self.next(); // consume opening `

    while (true)
    {
        char c = self.peek();

        // Handle end of file
        if (c == '\0')
        {
            return self.make_error_token("Unterminated raw string");
        }

        // Handle backtick
        if (c == '`')
        {
            self.next(); // consume first `

            // Check if it's an escaped backtick (``)
            if (self.peek() == '`')
            {
                self.next(); // consume second `
                continue; // This is an escaped backtick, keep scanning
            }
            else
            {
                // Single backtick means end of raw string
                break;
            }
        }

        // Regular character, just consume it
        self.next();
    }

    // At this point we've consumed the closing backtick
    Token token = self.make_token(TokenType.STRING);
    return token;
}

/**
 * Scan a regular string literal ("...")
 * Regular strings support escape sequences
 */
fn Token Lexer.scan_string(&self) @private
{
    self.next(); // consume opening "

    while (true)
    {
        char c = self.peek();

        // Handle end of file
        if (c == '\0')
        {
            return self.make_error_token("Unterminated string literal");
        }

        // Handle newline in string (not allowed in regular strings)
        if (c == '\n')
        {
            return self.make_error_token("Newline in string literal");
        }

        // Handle closing quote
        if (c == '"')
        {
            self.next(); // consume closing "
            break;
        }

        // Handle escape sequences
        if (c == '\\')
        {
            self.next(); // consume backslash
            char escape_char = self.peek();

            if (escape_char == '\0')
            {
                return self.make_error_token("Unterminated string literal");
            }

            if (escape_char == '\n')
            {
                // Backslash-newline is allowed for line continuation
                self.next(); // consume newline
                continue;
            }

            // Check for valid escape sequences
            char escaped = get_escape_char(escape_char);
            if (escaped != '\0' || escape_char == '0')
            {
                // Valid simple escape sequence
                self.next(); // consume escape character
            }
            else if (escape_char == 'x')
            {
                // Hex escape sequence \xNN
                self.next(); // consume 'x'
                if (!self.scan_string_hex_escape())
                {
                    return self.make_error_token("Invalid hex escape sequence in string");
                }
            }
            else if (escape_char == 'u')
            {
                // Unicode escape sequence \uNNNN
                self.next(); // consume 'u'
                if (!self.scan_string_unicode_escape(false))
                {
                    return self.make_error_token("Invalid unicode escape sequence in string");
                }
            }
            else if (escape_char == 'U')
            {
                // Unicode escape sequence \UNNNNNNNN
                self.next(); // consume 'U'
                if (!self.scan_string_unicode_escape(true))
                {
                    return self.make_error_token("Invalid unicode escape sequence in string");
                }
            }
            else
            {
                // Invalid escape sequence - consume the character anyway
                self.next();
                return self.make_error_token("Invalid escape sequence in string");
            }
        }
        else
        {
            // Regular character
            self.next();
        }
    }

    // At this point we've consumed the closing quote
    Token token = self.make_token(TokenType.STRING);
    return token;
}

/**
 * Scan hex escape sequence in string \xNN
 * Returns true if valid, false if invalid
 */
fn bool Lexer.scan_string_hex_escape(&self) @private
{
    // Expect exactly 2 hex digits
    for (int i = 0; i < 2; i++)
    {
        char c = self.peek();
        if (!c.is_xdigit())
        {
            return false;
        }
        self.next();
    }
    return true;
}

/**
 * Scan unicode escape sequence in string \uNNNN or \UNNNNNNNN
 * Returns true if valid, false if invalid
 */
fn bool Lexer.scan_string_unicode_escape(&self, bool is_long) @private
{
    int digits = is_long ? 8 : 4;

    // Expect exactly 4 or 8 hex digits
    for (int i = 0; i < digits; i++)
    {
        char c = self.peek();
        if (!c.is_xdigit())
        {
            return false;
        }
        self.next();
    }
    return true;
}

/**
 * Scan hex data literal (x"4865 6c6c 6f20 776f 726c 6421")
 * Supports x"...", x'...', and x`...` formats
 */
fn Token Lexer.scan_hex_array(&self) @private
{
    self.next(); // consume 'x'

    char quote_char = self.peek();
    if (quote_char != '"' && quote_char != '\'' && quote_char != '`')
    {
        return self.make_error_token("Expected quote after 'x' for hex array literal");
    }

    self.next(); // consume opening quote

    while (!self.reached_end() && self.peek() != quote_char)
    {
        char c = self.peek();

        // Skip whitespace in hex arrays (spaces are allowed for readability)
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r')
        {
            self.next();
            continue;
        }

        // Check for valid hex digits
        if (!c.is_xdigit())
        {
            return self.make_error_token("Invalid character in hex array literal");
        }

        self.next();
    }

    if (self.reached_end())
    {
        return self.make_error_token("Unterminated hex array literal");
    }

    // Handle escaped backticks for raw strings
    if (quote_char == '`')
    {
        // Check for escaped backticks (``)
        while (self.peek() == '`' && self.peek_next() == '`')
        {
            self.next(); // consume first `
            self.next(); // consume second `

            // Continue scanning for more content
            while (!self.reached_end() && self.peek() != '`')
            {
                char c = self.peek();
                if (c == ' ' || c == '\t' || c == '\n' || c == '\r')
                {
                    self.next();
                    continue;
                }
                if (!c.is_xdigit())
                {
                    return self.make_error_token("Invalid character in hex array literal");
                }
                self.next();
            }

            if (self.reached_end())
            {
                return self.make_error_token("Unterminated hex array literal");
            }
        }
    }

    self.next(); // consume closing quote

    return self.make_token(TokenType.HEX_ARRAY);
}

/**
 * Scan base64 data literal (b64"SGVsbG8gV29ybGQh")
 * Supports b64"...", b64'...', and b64`...` formats
 */
fn Token Lexer.scan_base64_array(&self) @private
{
    // We're at 'b', advance past it
    self.next();

    // Expect '64'
    if (self.peek() != '6' || self.peek_next() != '4')
    {
        return self.make_error_token("Expected '64' after 'b' for base64 literal");
    }

    self.next(); // consume '6'
    self.next(); // consume '4'

    char quote_char = self.peek();
    if (quote_char != '"' && quote_char != '\'' && quote_char != '`')
    {
        return self.make_error_token("Expected quote after 'b64' for base64 literal");
    }

    self.next(); // consume opening quote

    while (!self.reached_end() && self.peek() != quote_char)
    {
        char c = self.peek();

        // Skip whitespace in base64 arrays (spaces are allowed for readability)
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r')
        {
            self.next();
            continue;
        }

        // Check for valid base64 characters (A-Z, a-z, 0-9, +, /, =)
        if (!((c >= 'A' && c <= 'Z') ||
              (c >= 'a' && c <= 'z') ||
              (c >= '0' && c <= '9') ||
              c == '+' || c == '/' || c == '='))
        {
            return self.make_error_token("Invalid character in base64 literal");
        }

        self.next();
    }

    if (self.reached_end())
    {
        return self.make_error_token("Unterminated base64 literal");
    }

    // Handle escaped backticks for raw strings
    if (quote_char == '`')
    {
        // Check for escaped backticks (``)
        while (self.peek() == '`' && self.peek_next() == '`')
        {
            self.next(); // consume first `
            self.next(); // consume second `

            // Continue scanning for more content
            while (!self.reached_end() && self.peek() != '`')
            {
                char c = self.peek();
                if (c == ' ' || c == '\t' || c == '\n' || c == '\r')
                {
                    self.next();
                    continue;
                }
                if (!((c >= 'A' && c <= 'Z') ||
                      (c >= 'a' && c <= 'z') ||
                      (c >= '0' && c <= '9') ||
                      c == '+' || c == '/' || c == '='))
                {
                    return self.make_error_token("Invalid character in base64 literal");
                }
                self.next();
            }

            if (self.reached_end())
            {
                return self.make_error_token("Unterminated base64 literal");
            }
        }
    }

    self.next(); // consume closing quote

    return self.make_token(TokenType.BASE64_ARRAY);
}

/**
 * Scan 'b' tokens - could be base64 array or identifier
 */
fn Token Lexer.scan_b(&self) @private
{
    // Check if this is b64"..." (base64 literal)
    if (self.peek_next() == '6')
    {
        // Look ahead to see if it's "b64" followed by a quote
        if (self.current + 2 < self.source.len &&
            self.source[self.current + 2] == '4' &&
            self.current + 3 < self.source.len)
        {
            char quote_char = self.source[self.current + 3];
            if (quote_char == '"' || quote_char == '\'' || quote_char == '`')
            {
                return self.scan_base64_array();
            }
        }
    }

    // This is just a regular identifier starting with 'b'
    // Use the existing scan_ident function for regular identifiers (no prefix)
    return self.scan_ident(TokenType.IDENT, TokenType.CONST_IDENT, TokenType.TYPE_IDENT, '\0');
}

/**
 * Scan a digit, switching on initial zero for different number formats:
 * 0x... -> Hex
 * 0o... -> Octal
 * 0b... -> Binary
 * Default is decimal
 */
fn Token Lexer.scan_digit(&self) @private
{
    if (self.peek() == '0')
    {
        char next_char = self.peek_next();
        switch (next_char)
        {
            case 'x':
            case 'X':
                self.next(); // consume '0'
                self.next(); // consume 'x'
                return self.scan_hex_number();
            case 'o':
            case 'O':
                self.next(); // consume '0'
                self.next(); // consume 'o'
                return self.scan_oct_number();
            case 'b':
            case 'B':
                self.next(); // consume '0'
                self.next(); // consume 'b'
                return self.scan_binary_number();
            default:
                break;
        }
    }
    return self.scan_decimal_number();
}

/**
 * Scan decimal integer and float values
 */
fn Token Lexer.scan_decimal_number(&self) @private
{
    // Walk through the digits
    while (self.peek().is_digit() || self.peek() == '_')
    {
        if (self.peek() == '_')
        {
            self.next();
            // Check for multiple consecutive underscores
            if (self.peek() == '_')
            {
                return self.make_error_token("Multiple consecutive '_' are not allowed in numbers");
            }
        }
        else
        {
            self.next();
        }
    }

    bool is_float = false;

    // Check for decimal point (but not range operator ..)
    if (self.peek() == '.' && self.peek_next() != '.')
    {
        is_float = true;
        self.next(); // consume '.'

        // Check for invalid '_' directly after decimal point
        if (self.peek() == '_')
        {
            return self.make_error_token("'_' is not allowed directly after decimal point");
        }

        // Scan fractional part
        while (self.peek().is_digit() || self.peek() == '_')
        {
            if (self.peek() == '_')
            {
                self.next();
                if (self.peek() == '_')
                {
                    return self.make_error_token("Multiple consecutive '_' are not allowed in numbers");
                }
            }
            else
            {
                self.next();
            }
        }
    }

    // Check for exponential notation
    char c = self.peek();
    if (c == 'e' || c == 'E')
    {
        is_float = true;
        self.next(); // consume 'e' or 'E'

        // Optional sign
        c = self.peek();
        if (c == '+' || c == '-')
        {
            self.next();
        }

        // Must have at least one digit after exponent
        if (!self.peek().is_digit())
        {
            return self.make_error_token("Expected digit after exponent");
        }

        // Scan exponent digits
        while (self.peek().is_digit() || self.peek() == '_')
        {
            if (self.peek() == '_')
            {
                self.next();
                if (self.peek() == '_')
                {
                    return self.make_error_token("Multiple consecutive '_' are not allowed in numbers");
                }
            }
            else
            {
                self.next();
            }
        }
    }

    // Handle number suffixes (f32, i64, etc.)
    if (!self.scan_number_suffix(&is_float))
    {
        return self.make_error_token("Invalid number suffix");
    }

    return self.make_token(is_float ? TokenType.REAL : TokenType.INTEGER);
}

/**
 * Scan hexadecimal number (after 0x)
 * Includes floating point hex numbers and proper suffix handling
 */
fn Token Lexer.scan_hex_number(&self) @private
{
    // Must have at least one hex digit
    if (!self.peek().is_xdigit())
    {
        return self.make_error_token("Expected hexadecimal digit after '0x'");
    }

    // Scan the first hex digit
    self.next();

    // Continue scanning hex digits and underscores
    while (self.peek().is_xdigit() || self.peek() == '_')
    {
        if (self.peek() == '_')
        {
            self.next();
            if (self.peek() == '_')
            {
                return self.make_error_token("Multiple consecutive '_' are not allowed in numbers");
            }
        }
        else
        {
            self.next();
        }
    }

    bool is_float = false;

    // Check for hex floating point (0x123.abc)
    if (self.peek() == '.' && self.peek_next() != '.')
    {
        is_float = true;
        self.next(); // consume '.'

        // Check for invalid '_' directly after decimal point
        if (self.peek() == '_')
        {
            return self.make_error_token("'_' is not allowed directly after decimal point");
        }

        // Scan fractional hex digits (optional)
        if (self.peek().is_xdigit()) self.next();
        while (self.peek().is_xdigit() || self.peek() == '_')
        {
            if (self.peek() == '_')
            {
                self.next();
                if (self.peek() == '_')
                {
                    return self.make_error_token("Multiple consecutive '_' are not allowed in numbers");
                }
            }
            else
            {
                self.next();
            }
        }
    }

    // Check for hex exponent (p or P)
    char c = self.peek();
    if (c == 'p' || c == 'P')
    {
        is_float = true;
        self.next(); // consume 'p' or 'P'

        // Optional sign
        c = self.peek();
        if (c == '+' || c == '-')
        {
            self.next();
        }

        // Must have at least one digit after exponent
        if (!self.peek().is_digit())
        {
            return self.make_error_token("Expected digit after hex exponent");
        }

        // Scan exponent digits (decimal, not hex!)
        while (self.peek().is_digit() || self.peek() == '_')
        {
            if (self.peek() == '_')
            {
                self.next();
                if (self.peek() == '_')
                {
                    return self.make_error_token("Multiple consecutive '_' are not allowed in numbers");
                }
            }
            else
            {
                self.next();
            }
        }
    }

    // Handle number suffixes (f32, i64, etc.)
    if (!self.scan_number_suffix(&is_float))
    {
        return self.make_error_token("Invalid number suffix");
    }

    return self.make_token(is_float ? TokenType.REAL : TokenType.INTEGER);
}

/**
 * Scan octal number (after 0o)
 */
fn Token Lexer.scan_oct_number(&self) @private
{
    // Must have at least one octal digit
    char c = self.peek();
    if (!(c >= '0' && c <= '7'))
    {
        return self.make_error_token("Expected octal digit after '0o'");
    }

    while ((c = self.peek()) && ((c >= '0' && c <= '7') || c == '_'))
    {
        if (c == '_')
        {
            self.next();
            if (self.peek() == '_')
            {
                return self.make_error_token("Multiple consecutive '_' are not allowed in numbers");
            }
        }
        else
        {
            self.next();
        }
    }

    // Handle number suffixes
    bool is_float = false;
    if (!self.scan_number_suffix(&is_float))
    {
        return self.make_error_token("Invalid number suffix");
    }
    if (is_float)
    {
        return self.make_error_token("Octal literals cannot have a floating point suffix");
    }

    return self.make_token(TokenType.INTEGER);
}

/**
 * Scan binary number (after 0b)
 */
fn Token Lexer.scan_binary_number(&self) @private
{
    // Must have at least one binary digit
    char c = self.peek();
    if (c != '0' && c != '1')
    {
        return self.make_error_token("Expected binary digit after '0b'");
    }

    while ((c = self.peek()) && (c == '0' || c == '1' || c == '_'))
    {
        if (c == '_')
        {
            self.next();
            if (self.peek() == '_')
            {
                return self.make_error_token("Multiple consecutive '_' are not allowed in numbers");
            }
        }
        else
        {
            self.next();
        }
    }

    // Handle number suffixes
    bool is_float = false;
    if (!self.scan_number_suffix(&is_float))
    {
        return self.make_error_token("Invalid number suffix");
    }
    if (is_float)
    {
        return self.make_error_token("Binary literals cannot have a floating point suffix");
    }

    return self.make_token(TokenType.INTEGER);
}

/**
 * Scan number suffix (i8, i16, i32, i64, u8, u16, u32, u64, f32, f64, etc.)
 * For C3 we use the practice of f<bit-width> u<bit-width> and i<bit-width>
 */
fn bool Lexer.scan_number_suffix(&self, bool* is_float) @private
{
    // Check if number ended with '_' which is not allowed
    if (self.current > 0 && self.source[self.current - 1] == '_')
    {
        return false; // Error: number ended with '_'
    }

    char c = self.peek();
    if (!c.is_alnum() && c != '_') return true; // No suffix, that's fine

    switch (c | 32) // Convert to lowercase
    {
        case 'l':
            // Legacy C-style long suffix (ll or l)
            self.next();
            c = self.peek();
            if ((c | 32) == 'l') self.next(); // Handle 'll'
            if (*is_float)
            {
                return false; // Error: integer suffix on float
            }
            break;

        case 'u':
            // Unsigned suffix (u, ul, ull, or u<digits>)
            if (*is_float)
            {
                return false; // Error: integer suffix on float
            }
            self.next();
            c = self.peek();
            if ((c | 32) == 'l')
            {
                self.next();
                c = self.peek();
                if ((c | 32) == 'l') self.next(); // Handle 'ull'
                break;
            }
            // Handle u<digits> like u8, u16, u32, u64
            while (self.peek().is_digit()) self.next();
            break;

        case 'i':
            // Signed integer suffix (i<digits> like i8, i16, i32, i64)
            if (*is_float)
            {
                return false; // Error: integer suffix on float
            }
            self.next();
            if (!self.peek().is_digit())
            {
                return false; // Error: 'i' must be followed by bit width
            }
            while (self.peek().is_digit()) self.next();
            break;

        case 'd':
            // Double suffix (legacy)
            self.next();
            *is_float = true;
            break;

        case 'f':
            // Float suffix (f or f<digits> like f32, f64)
            self.next();
            *is_float = true;
            // Continue consuming digits after 'f'
            while (self.peek().is_digit()) self.next();
            break;

        default:
            break;
    }

    // Check if there are still alphanumeric characters (invalid suffix)
    c = self.peek();
    if (c.is_alnum() || c == '_')
    {
        return false; // Error: invalid literal suffix
    }

    return true;
}

/**
 * Scan 'x' tokens - could be hex array or identifier
 */
fn Token Lexer.scan_x(&self) @private
{
    char next_char = self.peek_next();
    if (next_char == '"' || next_char == '\'' || next_char == '`')
    {
        return self.scan_hex_array();
    }

    // This is just a regular identifier starting with 'x'
    // Use the existing scan_ident function for regular identifiers (no prefix)
    return self.scan_ident(TokenType.IDENT, TokenType.CONST_IDENT, TokenType.TYPE_IDENT, '\0');
}
