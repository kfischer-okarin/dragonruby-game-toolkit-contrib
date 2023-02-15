def test_text_position_movement(_args, assert)
  position = GTK::DocParser::TextPosition.new(<<~S)
    A1234567890
    B1234567890
    C1234567890
  S

  assert.equal! position.line_no, 0
  assert.equal! position.column, 0
  assert.equal! position.current_line, "A1234567890\n"
  assert.equal! position.current_char, 'A'
  assert.true! position.beginning_of_line?
  assert.false! position.end_of_line?

  position.move_by 3

  assert.equal! position.line_no, 0
  assert.equal! position.column, 3
  assert.equal! position.current_line, "A1234567890\n"
  assert.equal! position.current_char, '3'
  assert.false! position.beginning_of_line?
  assert.false! position.end_of_line?
  assert.false! position.end_of_string?

  position.move_by 10

  assert.equal! position.line_no, 1
  assert.equal! position.column, 1 # Count newline as a character
  assert.equal! position.current_line, "B1234567890\n"
  assert.equal! position.current_char, '1'

  position.move_by(-1)

  assert.equal! position.line_no, 1
  assert.equal! position.column, 0
  assert.equal! position.current_line, "B1234567890\n"
  assert.equal! position.current_char, 'B'

  position.move_by(-1)

  assert.equal! position.line_no, 0
  assert.equal! position.column, 11
  assert.equal! position.current_line, "A1234567890\n"
  assert.equal! position.current_char, "\n"
  assert.false! position.beginning_of_line?
  assert.true! position.end_of_line?

  position.move_by(14)

  assert.equal! position.line_no, 2
  assert.equal! position.column, 1

  position.move_by(100)

  assert.equal! position.line_no, 2
  assert.equal! position.column, 12
  assert.true! position.end_of_string?

  position.move_by(-100)

  assert.equal! position.line_no, 0
  assert.equal! position.column, 0
end

def test_text_position_current_string(_args, assert)
  position = GTK::DocParser::TextPosition.new(<<~S)
    Line 1
    Line 2
  S

  assert.equal! position.current_string(3), 'Lin'

  position.move_by 3

  assert.equal! position.current_string(8), "e 1\nLine"
end

def test_text_position_move_to_beginning_of_next_line(_args, assert)
  position = GTK::DocParser::TextPosition.new(<<~S)
    Line 1
    Line 2
  S
  position.move_by 3

  position.move_to_beginning_of_next_line

  assert.equal! position.line_no, 1
  assert.equal! position.column, 0
  assert.equal! position.current_string(6), 'Line 2'
end

def test_doc_parse_tokenize_header_and_markup(_args, assert)
  tokens = GTK::DocParser::Tokenizer.new(<<~S).tokens
    * DOCS: ~GTK::Args#audio~
    ** Header 2
    *** Header 3
    **** Header 4

    Audio docs
  S

  assert.equal! tokens, [
    :h1,
    'DOCS: ',
    :tilde,
    'GTK::Args#audio',
    :tilde,
    :newline,
    :h2,
    'Header 2',
    :newline,
    :h3,
    'Header 3',
    :newline,
    :h4,
    'Header 4',
    :newline,
    :newline,
    'Audio docs',
    :newline
  ]
end

def test_doc_parse_tokenize_code_block(_args, assert)
  tokens = GTK::DocParser::Tokenizer.new(<<~S).tokens
    Some Text

    #+begin_src
      def tick(args)
        args.outputs.labels << [100, 100, 'abc']
      end
    #+end_src

    More Text
  S

  assert.equal! tokens, [
    'Some Text',
    :newline,
    :newline,
    :code_block_start,
    { indent: 2 },
    'def tick(args)',
    :newline,
    { indent: 4 },
    'args.outputs.labels << [100, 100, \'abc\']',
    :newline,
    { indent: 2 },
    'end',
    :newline,
    :code_block_end,
    :newline,
    'More Text',
    :newline
  ]
end

def test_doc_parse_tokenize_link(_args, assert)
  tokens = GTK::DocParser::Tokenizer.new(<<~S).tokens
    Some Text with a link to [[http://discord.dragonruby.org]].
  S

  assert.equal! tokens, [
    'Some Text with a link to ',
    :link_start,
    'http://discord.dragonruby.org',
    :link_end,
    '.',
    :newline
  ]
end

def test_doc_parse_tokenize_ul(_args, assert)
  tokens = GTK::DocParser::Tokenizer.new(<<~S).tokens
    Text

    - ~id~ List one
      This is a description
    - ~sample_rate~ abc
  S

  assert.equal! tokens, [
    'Text',
    :newline,
    :newline,
    :ul,
    :tilde,
    'id',
    :tilde,
    ' List one',
    :newline,
    { indent: 2 },
    'This is a description',
    :newline,
    :ul,
    :tilde,
    'sample_rate',
    :tilde,
    ' abc',
    :newline
  ]
end

def test_doc_parse_headers_code_text_link(_args, assert)
  elements = GTK::ApiDocExport.parse_doc_entry <<~S
    * DOCS: ~GTK::Args#audio~
    ** Header 2
    *** Header 3
    **** Header 4

    Audio docs [[http://discord.dragonruby.org]]
  S

  assert.equal! elements, [
    {
      type: :h1,
      children: [
        'DOCS: ',
        { type: :code, children: ['GTK::Args#audio'] }
      ]
    },
    { type: :h2, children: ['Header 2'] },
    { type: :h3, children: ['Header 3'] },
    { type: :h4, children: ['Header 4'] },
    'Audio docs ',
    { type: :a, children: ['http://discord.dragonruby.org'] }
  ]
end

def test_doc_parse_ul(_args, assert)
  elements = GTK::ApiDocExport.parse_doc_entry <<~S
    Text

    - ~id~ List one
      This is a description
    - ~sample_rate~ abc

    More Text
  S

  assert.equal! elements, [
    'Text',
    {
      type: :ul,
      children: [
        { type: :code, children: ['id'] },
        ' List one This is a description'
      ]
    },
    {
      type: :ul,
      children: [
        { type: :code, children: ['sample_rate'] },
        ' abc'
      ]
    },
    'More Text'
  ]
end

def test_doc_parse_multiline_text(_args, assert)
  elements = GTK::ApiDocExport.parse_doc_entry <<~S
    Line 1
    Line 2
    Line 3
  S

  assert.equal! elements, [
    'Line 1 Line 2 Line 3'
  ]
end

def test_doc_parse_code_block(_args, assert)
  elements = GTK::ApiDocExport.parse_doc_entry <<~S
    #+begin_src
      def tick(args)
        args.outputs.labels << [100, 100, 'abc']
      end
    #+end_src
  S

  assert.equal! elements, [
    {
      type: :code_block,
      children: [
        'def tick(args)',
        '  args.outputs.labels << [100, 100, \'abc\']',
        'end'
      ]
    }
  ]
end
