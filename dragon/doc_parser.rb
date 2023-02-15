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
          if @text_position.beginning_of_line? && consume('* ')
            finish_text
            @tokens << :h1
          elsif @text_position.beginning_of_line? && consume('** ')
            finish_text
            @tokens << :h2
          elsif @text_position.beginning_of_line? && consume('*** ')
            finish_text
            @tokens << :h3
          elsif @text_position.beginning_of_line? && consume('**** ')
            finish_text
            @tokens << :h4
          elsif @text_position.beginning_of_line? && consume('#+begin_src')
            finish_text
            @tokens << :code_block_start
            @text_position.move_to_beginning_of_next_line
          elsif @text_position.beginning_of_line? && consume('#+end_src')
            finish_text
            @tokens << :code_block_end
            @text_position.move_to_beginning_of_next_line
          elsif consume('~')
            finish_text
            finish_indent
            @tokens << :tilde
          elsif consume("\n")
            finish_text
            finish_indent
            @tokens << :newline
          else
            if (@text_position.beginning_of_line? || @indent.positive?) && consume(' ')
              @indent += 1
              next
            end
            finish_indent
            @current_text << @text_position.current_char
            @text_position.move_by 1
          end
        end
      end

      private

      def consume(string)
        return false unless @text_position.current_string(string.length) == string

        @text_position.move_by string.length
        true
      end

      def finish_text
        return if @current_text.empty?

        @tokens << @current_text
        @current_text = ''
      end

      def finish_indent
        return unless @indent.positive?

        @tokens << { indent: @indent }
        @indent = 0
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
        when :h1, :h2, :h3, :h4
          element = { type: token, children: [] }
          @elements << element
          HeaderMode.new(element[:children], parent_mode: self)
        when :code_block_start
          element = { type: :code_block, children: [] }
          @elements << element
          CodeBlockMode.new(element[:children], parent_mode: self)
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

    class CodeBlockMode
      def initialize(elements, parent_mode:)
        @elements = elements
        @parent_mode = parent_mode
        @block_indent = nil
        @line_indent = nil
      end

      def parse_token(token)
        case token
        when :code_block_end
          @parent_mode
        when String
          string = token
          string = ' ' * (@line_indent - @block_indent) + string if @line_indent
          @elements << string
          self
        when :newline
          self
        when Hash
          if token.key? :indent
            @line_indent = token[:indent]
            # Indentation of the first line is the indentation of the block
            @block_indent ||= @line_indent
          end
          self
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
