# Copyright 2019 DragonRuby LLC
# MIT License
# wizards.rb has been released under MIT (*only this file*).

module GTK
  class SmaugClient
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

        attr_reader :authors, :description, :created_at, :version

        def initialize(json)
          @authors = json['authors']
          @description = json['description']
          @created_at = Version.parse_timestamp(json['created_at'])
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

      def authors
        latest_version.authors
      end

      def description
        latest_version.description
      end

      def last_updated
        latest_version.created_at
      end

      def latest_version
        @latest_version ||= @versions.sort_by(&:version).last
      end

      def inspect
        "#{@name} v#{latest_version}"
      end
    end

    class UI
      def self.get_letter_height(size_enum = nil)
        args = ["w"]
        args << size_enum if size_enum
        $gtk.calcstringbox(*args)[1]
      end

      class Table
        attr_rect

        attr_reader :x, :y, :w, :h, :selected_index

        def initialize(rect)
          @x, @y, @w, @h = rect
          @letter_height = UI.get_letter_height
          @v_padding = 2
          @columns = [
            { label: 'Name', width: @w - 100, package_method: :name },
            { label: 'Version', width: 100, package_method: :latest_version }
          ]
          @rows_area_height = @h - cell_height
          @selected_index = nil
        end

        def process_input(args, packages)
          return unless packages

          mouse = args.inputs.mouse
          return unless mouse.inside_rect?(self) && mouse.down

          @selected_index = nil
          y_in_table = mouse.y - @y
          clicked_index = (@rows_area_height - y_in_table).div cell_height
          @selected_index = clicked_index if (0...packages.size).include? clicked_index
        end

        def render(args, packages)
          args.outputs.reserved << [@x, @y, @w, @h, 255, 255, 255].border
          draw_table_headers(args.outputs)
          draw_table_rows(args, packages)
        end

        def draw_table_headers(outputs)
          x = @x
          y = top - cell_height
          @columns.each do |column|
            draw_cell(outputs, x: x, y: y, w: column[:width], text: column[:label], r: 100, g: 100, b: 100)
            x += column[:width]
          end
        end

        def draw_table_rows(args, packages)
          return unless packages

          rows_target = args.outputs[:smaug_table_rows]
          rows_target.width = @w
          rows_target.height = @rows_area_height
          x = 0
          y = @rows_area_height - cell_height
          packages.each_with_index do |package, index|
            @columns.each do |column|
              cell_values = { x: x, y: y, w: column[:width], text: package.send(column[:package_method]) }
              cell_values.update(r: 0, g: 100, b: 0) if index == @selected_index
              draw_cell(rows_target, cell_values)
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

      class DescriptionPanel
        attr_rect

        def initialize(rect)
          @x, @y, @w, @h = rect
          @header_height = UI.get_letter_height(4)
          @letter_height = UI.get_letter_height
          @link_rect = [0, 0, 0, 0]
          @link_text = 'View Package on smaug.dev'
          @link_width = $gtk.calcstringbox(@link_text)[0]
        end

        def render(args, package)
          args.outputs.reserved << [@x, @y, @w, @h, 255, 255, 255].border
          return unless package

          target = args.outputs[:smaug_description]
          target.width = @w
          target.height = @h

          position = [20, @h - 20]
          render_name_and_version(target, position, package)
          render_authors(target, position, package)
          render_description(target, position, package)
          render_visit_package_page_link(target, position, package)
          @link_rect = {
            x: @x + position.x,
            y: @y + position.y - @letter_height,
            w: @link_width,
            h: @letter_height
          }

          args.outputs.reserved << [@x, @y, @w, @h, :smaug_description].sprite
        end

        def process_input(args, package)
          return unless package

          mouse = args.inputs.mouse
          $gtk.openurl "https://smaug.dev/packages/#{package.name}" if mouse.down && mouse.inside_rect?(@link_rect)
        end

        private

        def render_name_and_version(outputs, position, package)
          outputs.reserved << { x: position.x, y: position.y, text: package.name, r: 255, g: 255, b: 255, size_enum: 4 }.label
          outputs.reserved << {
            x: position.x + @w - 40, y: position.y, text: package.latest_version,
            r: 255, g: 255, b: 255, size_enum: 2, alignment_enum: 2
          }.label

          position.y -= (@header_height + 10)
        end

        def render_authors(outputs, position, package)
          outputs.reserved << { x: position.x, y: position.y, text: 'Authors:', r: 255, g: 255, b: 255 }.label
          position.y -= (@letter_height + 5)

          package.authors.each do |author|
            wrapped_lines(author).each do |line|
              outputs.reserved << { x: position.x, y: position.y, text: line, r: 255, g: 255, b: 255 }.label
              position.y -= (@letter_height + 5)
            end
          end
        end

        def render_description(outputs, position, package)
          position.y -= 20

          wrapped_lines(package.description || '').each do |line|
            outputs.reserved << { x: position.x, y: position.y, text: line, r: 255, g: 255, b: 255 }.label
            position.y -= (@letter_height + 5)
          end
        end

        def render_visit_package_page_link(outputs, position, package)
          position.y -= 20

          outputs.reserved << { x: position.x, y: position.y, text: @link_text, r: 150, g: 150, b: 238 }.label
          underline_y = position.y - @letter_height
          outputs.reserved << { x: position.x, y: underline_y, x2: position.x + @link_width, y2: underline_y, r: 150, g: 150, b: 238 }.line
        end

        def wrapped_lines(string)
          max_length = @w - 40
          length = $gtk.calcstringbox(string)[0]
          return [string] if length <= max_length

          [].tap { |result|
            start_index = 0
            line_end_index = -1
            search_start_index = 1
            loop do
              end_of_next_word_index = string.index(' ', search_start_index)
              end_of_next_word_index ||= string.size
              end_of_next_word_index -= 1
              line_end_index = end_of_next_word_index if line_end_index <= start_index

              if $gtk.calcstringbox(string[start_index..end_of_next_word_index])[0] > max_length
                result << string[start_index..line_end_index]
                break if line_end_index == -1

                start_index = line_end_index + 1
                start_index += 1 while string[start_index] == ' '
              else
                line_end_index = end_of_next_word_index
                if line_end_index == string.size - 1
                  result << string[start_index..line_end_index]
                  break
                end

                search_start_index = end_of_next_word_index + 1
                search_start_index += 1 while string[search_start_index] == ' '
              end
            end
          }
        end
      end

      attr_rect

      attr_reader :x, :y, :w, :h

      def initialize(client)
        @client = client
        @x, @y, @w, @h = [300, 100, 680, 520]
        @close_button_rect = [right - 30, top - 30, 25, 25]
        @table = Table.new([left + 5, bottom + 5, 300, @h - 5 - 35])
        @description = DescriptionPanel.new([@table.right, @table.bottom, @w - @table.w - 10, @table.h])
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
        @table.process_input(args, @client.packages)
        @description.process_input(args, selected_package)

        args.inputs.mouse.clear if args.inputs.mouse.inside_rect? self
      end

      def render(args)
        return unless @visible

        draw_window(args.outputs)
        draw_x_button(args.outputs, @close_button_rect)
        @table.render(args, @client.packages)
        @description.render(args, selected_package)
      end

      def tick(args)
        render(args)
        process_input(args)
      end

      private

      def draw_window(gtk_outputs)
        gtk_outputs.reserved << [@x, @y, @w, @h, 255, 255, 255].border
        gtk_outputs.reserved << [@x + 1, @y + 1, @w - 2, @h - 2, 0, 0, 0].solid
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

      def selected_package
        return nil unless @client.packages && @table.selected_index

        @client.packages[@table.selected_index]
      end
    end

    attr_reader :packages

    def initialize
      @windows = $gtk.platform == 'Windows'
      @dr_directory = $gtk.binary_path[0..-12] # remove last 11 characters ("/dragonruby") from binary path
      @request = nil
      @state = { name: :get_latest_smaug_release }
      @state[:current_version] = `cat .smaug-version`.strip if file_exists? path_to(smaug_executable)
      @ui = UI.new(self)
    end

    def show
      @ui.show
    end

    def tick(args)
      return unless @ui.visible?

      send(:"#{@state[:name]}_tick", args)
    end

    def get_latest_smaug_release_tick(args)
      @request ||= $gtk.http_get 'https://api.github.com/repos/ereborstudios/smaug/releases/latest'
      return unless @request[:complete]

      if @request[:http_response_code] == 200
        response = $gtk.parse_json @request[:response_data]
        if @state[:current_version] != response['tag_name']
          @state = {
            name: :download_smaug,
            release: { version: response['tag_name'], url: get_download_url(response['assets']) }
          }
        else
          @state = { name: :load_packages }
        end
      else
        @state = { name: :error, message: 'Error while downloading Smaug' }
      end
      @request = nil
    end

    def download_smaug_tick(args)
      @request ||= $gtk.http_get @state[:release][:url]
      return unless @request[:complete]

      if @request[:http_response_code] == 200
        response = @request[:response_data]
        $gtk.write_file_root(smaug_executable, response)
        $gtk.system "chmod u+x #{path_to(smaug_executable)}" unless @windows
        write_version_file
        @state = { name: :load_packages }
      elsif @request[:http_response_code] == 302
        @state[:release][:url] = @request[:headers]['location']
      else
        @state = { name: :error, message: 'Error while downloading Smaug' }
      end
      @request = nil
    end

    def load_packages_tick(args)
      # TODO: $gtk.parse_json `#{path_to(smaug_executable)} list --json`.strip
      @request ||= $gtk.http_get 'https://api.smaug.dev/packages'
      return unless @request[:complete]

      if @request[:http_response_code] == 200
        package_jsons = $gtk.parse_json @request[:response_data]
        @packages = package_jsons.map { |package_json| Package.new(package_json) }
        @state = { name: :packages_loaded }
      else
        @state =  { name: :error, message: 'Error while loading packages' }
      end
    end

    def packages_loaded_tick(args)
      @ui.tick(args)
    end

    def file_exists?(file)
      if @windows
        `cmd /c if exist #{file} echo 1`.strip == '1'
      else
        `[ -e #{file} ] && echo 1`.strip == '1'
      end
    end

    def path_to(filename)
      "#{@dr_directory}/#{filename}"
    end

    def smaug_executable
      @smaug_executable ||= @windows ? "smaug.exe" : "smaug"
    end

    SMAUG_VERSION_FILE = '.smaug-version'.freeze

    def write_version_file
      $gtk.write_file_root(SMAUG_VERSION_FILE, @state[:release][:version])
    end

    def get_download_url(assets_json)
      asset = assets_json.find { |asset_json| asset_of_current_platform?(asset_json) }
      asset['browser_download_url']
    end

    def asset_of_current_platform?(asset_json)
      case $gtk.platform
      when 'Windows'
        asset_json['name'].include? 'windows'
      when 'Mac OS X'
        asset_json['name'].include? 'mac'
      when 'Linux'
        asset_json['name'].include? 'linux'
      else
        false
      end
    end
  end
end
