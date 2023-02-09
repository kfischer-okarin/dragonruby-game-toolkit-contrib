def test_doc_parse_tokenize(args, assert)
  tokens = GTK::DocParser::Tokenizer.new(<<~S).tokens
    * DOCS: ~GTK::Args#audio~

    Audio docs
  S

  assert.equal! tokens, [
    :h1,
    'DOCS: ',
    :tilde,
    'GTK::Args#audio',
    :tilde,
    :newline,
    :newline,
    'Audio docs',
    :newline
  ]
end

def test_doc_parse_header_code_text(args, assert)
  elements = GTK::ApiDocExport.parse_doc_entry <<~S
    * DOCS: ~GTK::Args#audio~

    Audio docs
  S

  assert.equal! elements, [
    {
      type: :h1,
      children: [
        'DOCS: ',
        { type: :code, children: ['GTK::Args#audio'] }
      ]
    },
    'Audio docs'
  ]
end

def test_doc_parse_multiline_text(args, assert)
  elements = GTK::ApiDocExport.parse_doc_entry <<~S
    Line 1
    Line 2
    Line 3
  S

  assert.equal! elements, [
    'Line 1 Line 2 Line 3',
  ]
end
