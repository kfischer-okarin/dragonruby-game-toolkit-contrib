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
