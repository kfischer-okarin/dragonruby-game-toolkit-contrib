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
        @text_position = TextPosition.new(doc_string)
        @tokens = []
        @current_text = ''

        tokenize
      end

      def tokenize
        until @text_position.end_of_string?
          char = @text_position.current_char

          case char
          when '*'
            finish_text
            @tokens << :h1
            @text_position.move_by 1
          when '~'
            finish_text
            @tokens << :tilde
          when "\n"
            finish_text
            @tokens << :newline
          else
            @current_text << char
          end

          @text_position.move_by 1
        end
      end

      private

      def finish_text
        return if @current_text.empty?

        @tokens << @current_text
        @current_text = ''
      end
    end

    class TextPosition
      attr_reader :line_no, :column

      def initialize(string)
        @string = string
        @index = 0
        @lines = string.lines
        @line_no = 0
        @column = 0
      end

      def current_line
        @lines[@line_no]
      end

      def current_char
        current_line[@column]
      end

      def current_string(count)
        @string[@index, count]
      end

      def beginning_of_line?
        @column.zero?
      end

      def end_of_line?
        @column == current_line.length - 1
      end

      def end_of_string?
        @index == @string.length
      end

      def move_by(count)
        @index += count
        @column += count
        handle_move_to_next_line
        handle_move_to_previous_line
      end

      private

      def handle_move_to_next_line
        while @column >= current_line.length
          if @line_no == @lines.length - 1
            @index = @string.length
            @column = current_line.length
            return
          end

          @column -= current_line.length
          @line_no += 1
        end
      end

      def handle_move_to_previous_line
        while @column.negative?
          if @line_no.zero?
            @index = 0
            @column = 0
            return
          end

          @line_no -= 1
          @column += current_line.length
        end
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
