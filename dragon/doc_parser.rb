module GTK
  class DocParser
    def parse(doc_string)
      tokens = Tokenizer.new(doc_string).tokens
      index = 0
      elements = []
      h1 = nil
      code = nil
      text = ''

      while index < tokens.length
        token = tokens[index]

        case token
        when :h1
          h1 = { type: :h1, children: [] }
        when :tilde
          if code
            code[:children] << text
            text = ''
            if h1
              h1[:children] << code
            end
          else
            if h1
              h1[:children] << text
              text = ''
            end
            code = { type: :code, children: [] }
          end
        when :newline
          if h1
            h1[:children] << text if text.length > 0
            elements << h1
            h1 = nil
          else
            elements << text if text.length > 0
          end
        else
          text = token
        end

        index += 1
      end
      elements
    end

    private

    class Tokenizer
      attr_reader :tokens

      def initialize(doc_string)
        @chars = doc_string.chars
        @index = 0
        @tokens = []
        @current_text = ''

        tokenize
      end

      def tokenize
        while @index < @chars.length
          char = @chars[@index]

          case char
          when '*'
            finish_text
            @tokens << :h1
            @index += 1
          when '~'
            finish_text
            @tokens << :tilde
          when "\n"
            finish_text
            @tokens << :newline
          else
            @current_text << char
          end

          @index += 1
        end
      end

      def finish_text
        return if @current_text.empty?

        @tokens << @current_text
        @current_text = ''
      end
    end
  end
end
