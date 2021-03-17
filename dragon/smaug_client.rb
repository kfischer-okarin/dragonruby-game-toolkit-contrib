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
          @repository = json['repository']
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

    class << self
      def get_packages_json_from_api
        $gtk.parse_json `curl https://api.smaug.dev/packages` # FIXME: $gtk.http_get 'https://api.smaug.dev/packages'
      end

      def get_packages_from_api
        packages_json = get_packages_json_from_api
        packages_json.map { |package_json| Package.new(package_json) }
      end
    end
  end
end
