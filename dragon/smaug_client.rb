# Copyright 2019 DragonRuby LLC
# MIT License
# wizards.rb has been released under MIT (*only this file*).

module GTK
  class SmaugClient
    class << self
      def list_packages
        # FIXME: $gtk.http_get 'https://api.smaug.dev/packages'
        [
          {
            "name" => "color",
            "versions" => [
              {
                "repository" => {
                  "url" => "https://gitlab.com/ereborstudios/color.git",
                  "tag" => "0.1.2"
                },
                "version" => "0.1.2",
                "authors" => ["Logan Koester \u003clogan@logankoester.com\u003e"],
                "description" => "Color manipulation utilities for DragonRuby",
                "created_at" => "2021-03-11T08:35:47.896Z"
              }
            ]
          },
          {
            "name" => "draco",
            "versions" => [
              {
                "repository" => {
                  "url" => "git://github.com/guitsaru/draco.git",
                  "tag" => "v0.6.1"
                },
                "version" => "0.6.1",
                "authors" => ["Matt Pruitt \u003cmatt@guitsaru.com\u003e"],
                "description" => "An Entity Component System for DragonRuby GTK",
                "created_at" => "2021-03-11T09:43:08.779Z"
              }
            ]
          },
          {
            "name" => "draco-common",
            "versions" => [
              {
                "repository" => {
                  "url" => "https://gitlab.com/ereborstudios/draco-common.git",
                  "tag" => "0.1.1"
                },
                "version" => "0.1.1",
                "authors" => ["Logan Koester \u003clogan@logankoester.com\u003e"],
                "description" => "This package adds some common components and systems to your Draco project to help you get started.",
                "created_at" => "2021-03-11T08:40:35.131Z"
              }
            ]
          },
          {
            "name" => "draco-events",
            "versions" => [
              {
                "repository" => {
                  "url" => "git://github.com/guitsaru/draco-events.git",
                  "tag" => "v0.2.0"
                },
                "version" => "0.2.0",
                "authors" => ["Matt Pruitt \u003cmatt@guitsaru.com\u003e"],
                "description" => "An event bus and observer plugin for the Draco ECS library.",
                "created_at" => "2021-03-11T14:07:30.734Z"
              }
            ]
          },
          {
            "name" => "draco-periodic",
            "versions" => [
              {
                "repository" => {
                  "url" => "git://github.com/guitsaru/draco-periodic.git",
                  "tag" => "v0.2.0"
                },
                "version" => "0.2.0",
                "authors" => ["Matt Pruitt \u003cmatt@guitsaru.com\u003e"],
                "description" => "Run a Draco System every n ticks",
                "created_at" => "2021-03-11T14:13:22.049Z"
              }
            ]
          },
          {
            "name" => "draco-scenes",
            "versions" => [
              {
                "repository" => {
                  "url" => "git://github.com/guitsaru/draco-scenes.git",
                  "tag" => "v0.2.0"
                },
                "version" => "0.2.0",
                "authors" => ["Matt Pruitt \u003cmatt@guitsaru.com\u003e"],
                "description" => "A scene definition DSL for the Draco ECS library.",
                "created_at" => "2021-03-11T14:16:28.074Z"
              }
            ]
          },
          {
            "name" => "draco-state",
            "versions" => [
              {
                "repository" => {
                  "url" => "git://github.com/guitsaru/draco-state.git",
                  "tag" => "v0.2.0"
                },
                "version" => "0.2.0",
                "authors" => ["Matt Pruitt \u003cmatt@guitsaru.com\u003e"],
                "description" => "A State management implementation for the Draco ECS framework.",
                "created_at" => "2021-03-11T14:23:37.289Z"
              }
            ]
          },
          {
            "name" => "zif",
            "versions" => [
              {
                "repository" => {
                  "url" => "git://github.com/logankoester/dragonruby-zif.git",
                  "tag" => "smaug"
                },
                "version" => "2.0.0-rc.2",
                "authors" => ["Dan Healy \u003cdan@beyondludus.com\u003e"],
                "description" => "Zif: A Drop-in Framework for DragonRuby GTK",
                "created_at" => "2021-03-11T17:29:15.698Z"
              }
            ]
          }
        ]
      end
    end
  end
end
