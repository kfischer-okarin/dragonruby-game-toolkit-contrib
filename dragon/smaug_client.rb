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

        attr_reader :author, :description, :created_at, :version

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

    # $gtk.openurl 'url' to open package page

    class UI
      def self.get_letter_height(size_enum = nil)
        args = ["w"]
        args << size_enum if size_enum
        $gtk.calcstringbox(*args)[1]
      end

      class Table
        attr_rect

        attr_reader :x, :y, :w, :h

        def initialize(rect)
          @x, @y, @w, @h = rect
          @letter_height = UI.get_letter_height
          @v_padding = 2
          @columns = [
            { label: 'Name', width: @w - 100, package_method: :name },
            { label: 'Version', width: 100, package_method: :latest_version }
          ]
          @rows_area_height = @h - cell_height
        end

        def process_input(args)
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
          packages.each do |package|
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

      attr_rect

      attr_reader :x, :y, :w, :h

      def initialize(client)
        @client = client
        @x, @y, @w, @h = [300, 100, 680, 520]
        @close_button_rect = [right - 30, top - 30, 25, 25]
        @table = Table.new([left + 5, bottom + 45, 300, @h - 50 - 30])
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

        args.inputs.mouse.clear if args.inputs.mouse.inside_rect? self
      end

      def render(args)
        return unless @visible

        draw_window(args.outputs)
        draw_x_button(args.outputs, @close_button_rect)
        @table.render(args, @client.packages)
      end

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
      @request = $gtk.http_get 'https://api.smaug.dev/packages'
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
      @ui.render(args)
      @ui.process_input(args)
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
