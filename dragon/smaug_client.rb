# Copyright 2019 DragonRuby LLC
# MIT License
# wizards.rb has been released under MIT (*only this file*).

module GTK
  class SmaugClient
    class GithubSource
      GITHUB_PREFIX = 'git://github.com/'.freeze
      GITHUB_SUFFIX = '.git'.freeze

      def self.applicable?(version_json)
        version_json.dig('repository', 'url')&.start_with? GITHUB_PREFIX
      end

      def initialize(version_json)
        repository_json = version_json['repository']

        # git://github.com/user/repository.git -> https://codeload.github.com/user/repository/zip/tag
        @download_url = 'https://codeload.github.com/' +
                        repository_json['url'][GITHUB_PREFIX.size...-GITHUB_SUFFIX.size] +
                        '/zip/' +
                        repository_json['tag']
      end

      def to_s
        "Github(#{@download_url})"
      end
    end

    class GitlabSource
      def self.applicable?(version_json)
        version_json.dig('repository', 'url')&.start_with? 'https://gitlab.com'
      end

      def self.repository_name(repository_url)
        last_slash_index = repository_url.rindex('/')
        repository_url[(last_slash_index + 1)..-1]
      end

      def initialize(version_json)
        repository_json = version_json['repository']

        repository_url = repository_json['url']
        tag = repository_json['tag']
        repository_name = GitlabSource.repository_name(repository_url)
        # https://gitlab.com/ereborstudios/color -> https://gitlab.com/ereborstudios/color/-/archive/0.1.2/color-0.1.2.zip
        @download_url = repository_url + "/-/archive/#{tag}/#{repository_name}-#{tag}.zip"
      end

      def to_s
        "Gitlab(#{@download_url})"
      end
    end

    class Package
      class Version
        def self.parse_version_string(version)
          version.split('.').map(&:to_i)
        end

        # 2021-03-11T14:23:37.289Z
        def self.parse_timestamp(timestamp)
          Time.new(
            timestamp[0..3].to_i, # Year
            timestamp[5..6].to_i, # Month
            timestamp[8..9].to_i, # Day
            timestamp[11..12].to_i, # Hour
            timestamp[14..15].to_i, # Minute
            timestamp[17..18].to_i, # Second
          )
        rescue ArgumentError
          puts "Invalid timestamp #{timestamp}"
        end

        attr_reader :author, :description, :created_at, :version, :source

        def initialize(json)
          @authors = json['authors']
          @description = json['description']
          @created_at = Version.parse_timestamp(json['created_at'])
          source_class = [GithubSource, GitlabSource].find { |klass| klass.applicable? json }
          @source = source_class.new(json)
          @version = Version.parse_version_string(json['version'])
        end

        def to_s
          @version.map(&:to_s).join('.')
        end
      end

      attr_reader :name, :versions

      def initialize(json)
        @name = json['name']
        @versions = json['versions'].map { |version_json| Version.new(version_json) }
      end

      def author
        latest_version.author
      end

      def description
        latest_version.description
      end

      def last_updated
        latest_version.created_at
      end

      def latest_version
        @latest_version ||= @versions.max_by { |version| version.version }
      end

      def inspect
        "Package '#{@name}' (latest version #{latest_version}, last updated: #{last_updated})"
      end
    end

    class UI
      class Table
        attr_rect

        def initialize(client, rect)
          @client = client
          @x, @y, @w, @h = rect
          @letter_height = $gtk.calcstringbox("W")[1]
          @v_padding = 2
          @columns = [
            { label: 'Name', width: @w - 100, package_method: :name },
            { label: 'Version', width: 100, package_method: :latest_version }
          ]
          @rows_area_height = @h - cell_height
        end

        def process_input(args)
        end

        def render(args)
          args.outputs.reserved << [@x, @y, @w, @h, 255, 255, 255].border
          draw_table_headers(args.outputs)
          draw_table_rows(args)
        end

        def draw_table_headers(outputs)
          x = @x
          y = top - cell_height
          @columns.each do |column|
            draw_cell(outputs, x: x, y: y, w: column[:width], text: column[:label], r: 100, g: 100, b: 100)
            x += column[:width]
          end
        end

        def draw_table_rows(args)
          return unless @client.packages

          rows_target = args.outputs[:smaug_table_rows]
          rows_target.width = @w
          rows_target.height = @rows_area_height
          x = 0
          y = @rows_area_height - cell_height
          @client.packages.each do |package|
            @columns.each do |column|
              draw_cell(rows_target, x: x, y: y, w: column[:width], text: package.send(column[:package_method]))
              x += column[:width]
            end
            y -= cell_height
            x = 0
            break if y < -cell_height
          end
          args.outputs.reserved << [@x, @y, @w, @rows_area_height, :smaug_table_rows].sprite
        end

        def draw_cell(outputs, values)
          outputs.reserved << [values[:x], values[:y], values[:w], cell_height, 255, 255, 255].border
          if values[:r]
            bg = [values[:x] + 1, values[:y] + 1, values[:w] - 2, cell_height - 2, values[:r], values[:g], values[:b]].solid
            outputs.reserved << bg
          end
          outputs.reserved << {
            x: values[:x] + values[:w] / 2,
            y: values[:y] + @v_padding + @letter_height,
            text: values[:text],
            alignment_enum: 1,
            r: 255, g: 255, b: 255
          }.label
        end

        private

        def cell_height
          @letter_height + @v_padding * 2
        end
      end

      def initialize(client)
        @client = client
        @window_rect = [300, 100, 680, 520]
        @close_button_rect = [@window_rect.right - 30, @window_rect.top - 30, 30, 30]
        @table_rect = [@window_rect.left + 5, @window_rect.bottom + 45, 300, @window_rect.h - 50 - 30]
        @table = Table.new(client, @table_rect)
        @visible = false
      end

      def visible?
        @visible
      end

      def show
        @visible = true
      end

      def process_input(args)
        return unless @visible

        handle_x_button_click(args.inputs)
        @table.process_input(args)

        args.inputs.mouse.clear if args.inputs.mouse.inside_rect?(@window_rect)
      end

      def render(args)
        return unless @visible

        draw_window(args.outputs, @window_rect)
        draw_x_button(args.outputs, @close_button_rect)
        @table.render(args)
      end

      def draw_window(gtk_outputs, rect)
        gtk_outputs.reserved << [rect.x, rect.y, rect.w, rect.h, 255, 255, 255].border
        gtk_outputs.reserved << [rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2, 0, 0, 0].solid
      end

      def draw_x_button(gtk_outputs, rect)
        gtk_outputs.reserved << [rect.x, rect.y, rect.w, rect.h, 200, 200, 200].solid
        gtk_outputs.reserved << [rect.x, rect.y, rect.x + rect.w, rect.y + rect.h, 0, 0, 0].line
        gtk_outputs.reserved << [rect.x + rect.w, rect.y, rect.x, rect.y + rect.h, 0, 0, 0].line
      end

      def handle_x_button_click(gtk_inputs)
        return unless gtk_inputs.mouse.click && gtk_inputs.mouse.inside_rect?(@close_button_rect)

        @visible = false
      end
    end

    attr_reader :packages

    def initialize
      @request = nil
      @state = :initial
      @ui = UI.new(self)
    end

    def show
      @ui.show
      load_packages unless @packages
    end

    def render(args)
      return unless $console.ready?

      @ui.render(args)

      case @state
      when :loading_packages
        return unless @request[:complete]

        if @request[:http_response_code] == 200
          package_jsons = $gtk.parse_json @request[:response_data]
          @packages = package_jsons.map { |package_json| Package.new(package_json) }
          @state = :packages_loaded
        else
          @state = :error
        end
      end
    end

    def process_input(args)
      return unless $console.ready?

      @ui.process_input(args)
    end

    def load_packages
      @request = $gtk.http_get 'https://api.smaug.dev/packages'
      @state = :loading_packages
    end
  end
end
