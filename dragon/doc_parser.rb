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
        @indent = 0

        tokenize
      end

      def tokenize
        until @text_position.end_of_string?
          char = @text_position.current_char

          if @text_position.beginning_of_line? && @text_position.current_string(2) == '* '
            finish_text
            @tokens << :h1
            @text_position.move_by 2
          elsif @text_position.beginning_of_line? && @text_position.current_string(11) == '#+begin_src'
            finish_text
            @tokens << :code_block_start
            @text_position.move_to_beginning_of_next_line
            @indent = calc_indent @text_position.current_line
          elsif @text_position.beginning_of_line? && @text_position.current_string(9) == '#+end_src'
            finish_text
            @tokens << :code_block_end
            @text_position.move_to_beginning_of_next_line
            @indent = 0
          elsif char == '~'
            finish_text
            @tokens << :tilde
            @text_position.move_by 1
          elsif char == "\n"
            finish_text
            @tokens << :newline
            @text_position.move_by 1
          else
            @current_text << char
            @text_position.move_by 1
          end
        end
      end

      private

      def finish_text
        return if @current_text.empty?

        @tokens << @current_text[@indent..-1]
        @current_text = ''
      end

      def calc_indent(line)
        result = 0
        line.each_char do |char|
          break unless char == ' '

          result += 1
        end
        result
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

      def move_to_beginning_of_next_line
        move_by current_line.length - @column
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
