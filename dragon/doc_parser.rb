module GTK
  class DocParser
    def initialize
      @elements = []
      @mode = RootMode.new(@elements)
    end

    def parse(doc_string)
      tokens = Tokenizer.new(doc_string).tokens

      tokens.each do |token|
        @mode = @mode.parse_token token
      end

      @elements
    end

    private

    class Tokenizer
      attr_reader :tokens

      def initialize(doc_string)
        @lines = doc_string.lines
        @line_no = 0
        @column = 0
        @tokens = []
        @current_text = ''

        tokenize
      end

      def tokenize
        until end_of_string?
          char = current_char

          case char
          when '*'
            finish_text
            @tokens << :h1
            move_index 1
          when '~'
            finish_text
            @tokens << :tilde
          when "\n"
            finish_text
            @tokens << :newline
          else
            @current_text << char
          end

          move_index 1
        end
      end

      private

      def end_of_string?
        @line_no == @lines.length - 1 && @column == @lines.last.length
      end

      def current_char
        @lines[@line_no][@column]
      end

      def move_index(count)
        @column += count

        while @column >= @lines[@line_no].length
          if @line_no == @lines.length - 1
            @column = @lines.last.length
            break
          end

          @line_no += 1
          @column = 0
        end
      end

      def finish_text
        return if @current_text.empty?

        @tokens << @current_text
        @current_text = ''
      end
    end

    class RootMode
      def initialize(elements)
        @elements = elements
      end

      def parse_token(token)
        last_element = @elements.last

        case token
        when :h1
          element = { type: :h1, children: [] }
          @elements << element
          HeaderMode.new(element[:children], parent_mode: self)
        when String
          if last_element.is_a?(String)
            @elements[-1] = "#{last_element} #{token}"
          else
            @elements << token
          end
          self
        else
          self
        end
      end
    end

    class HeaderMode
      def initialize(elements, parent_mode:)
        @elements = elements
        @parent_mode = parent_mode
      end

      def parse_token(token)
        case token
        when :tilde
          element = { type: :code, children: [] }
          @elements << element
          CodeMode.new(element[:children], parent_mode: self)
        when String
          @elements << token
          self
        when :newline
          @parent_mode
        end
      end
    end

    class CodeMode
      def initialize(elements, parent_mode:)
        @elements = elements
        @parent_mode = parent_mode
      end

      def parse_token(token)
        case token
        when String
          @elements << token
          self
        when :tilde
          @parent_mode
        end
      end
    end
  end
end
