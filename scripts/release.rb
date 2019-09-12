#!/usr/bin/env ruby

# release.rb
#
# SUMMARY
#
#   A script that formalizes the Vector release process. This script
#   specifically does the following:
#
#     1. fill in
#
#   See the README.md in the release folder for more details.

Dir.chdir "scripts/release"

#
# Require
#

require "rubygems"
require "bundler"
Bundler.require(:default)

require "active_support/core_ext/array/conversions"
require "active_support/core_ext/string/filters"
require "active_support/core_ext/string/indent"
require "active_support/core_ext/string/inflections"
require "action_view/helpers/number_helper"
require "erb"
require "logger"
require "pathname"

require_relative "util/version"
require_relative "release/commit"
require_relative "release/github"
require_relative "release/release"
require_relative "release/scope"
require_relative "release/templates"

#
# Constants
#

DOCS_DIR = Pathname.new("#{Dir.pwd}/../../docs").cleanpath
GITHUB = Github.new
GITHUB_ORG = "timberio"
GITHUB_REPO = "vector"
LAST_COMMIT = `git rev-parse HEAD`.chomp
LAST_TAG = `git describe --abbrev=0`.chomp
LAST_VERSION = Version.new(LAST_TAG.gsub(/^v/, ''))
RELEASE_NOTES_DIR = "#{DOCS_DIR}/meta/release-notes"
SAY_PREFIX = "---> "
SAY_INDENT = "     "
SEPARATOR = "-" * 80
TMP_LOG_FILE = "#{Dir.pwd}/.staged_commits.tmp"
UPGRADE_GUIDES_DIR = "#{DOCS_DIR}/usage/administration/updating"

LOGGER = Logger.new(STDOUT)
LOGGER.formatter = proc do |_severity, _datetime, _progname, msg|
  "#{SAY_PREFIX}#{msg}\n"
end

#
# Writing
#

def error!(message)
  say(message, color: :red)
  exit(1)
end

def get(words, choices = nil)
  question = "#{words.strip}"

  if !choices.nil?
    question += " (" + choices.join("/") + ")"
  end

  say(question)

  print SAY_INDENT
  input = gets.chomp

  if choices && !choices.include?(input)
    say("You must enter one of #{choices.to_sentence(last_word_connector: ", or ")}", color: :red)
    get(words, choices)
  else
    input
  end
end

def invalid(words)
  say(words, color: :orange)
end

def say(words, color: nil, new: true)
  if color
    words = Paint[words, color]
  end

  indented_words = words.gsub("\n", "\n#{SAY_INDENT}")

  puts "#{new ? SAY_PREFIX : SAY_INDENT}#{indented_words}"
end

#
# Release Functions
#

def get_new_version
  version_string = get("What is the next version you are releasing? (current version is #{LAST_VERSION})")

  version =
    begin
      Version.new(version_string)
    rescue ArgumentError => e
      invalid("It looks like the version you entered is invalid: #{e.message}")
      get_new_version
    end

  if LAST_VERSION.bump_type(version).nil?
    invalid("The version you entered must be a single patch, minor, or major bump")
    get_new_version
  else
    version
  end
end

def get_commit_lines(range)
  log = `git log #{range} --no-merges --pretty=format:'%H\t%s\t%aN\t%ad'`

  if File.exists?(TMP_LOG_FILE)
    words =
      <<~EOF
      It looks like you've already staged commits for this release in:

        #{TMP_LOG_FILE}

      Would you like to reuse this file?
      EOF

    input = get(words, ["y", "n"])

    if input == "n"
      File.delete(TMP_LOG_FILE)
      say("File deleted")
      get_commit_lines(range)
    end
  else
    File.open(TMP_LOG_FILE, 'w+') do |file|
      file.write(log)
    end

    say(
      <<~EOF
      I've staged all commits for this release in the follow file:

        #{TMP_LOG_FILE}

      Please modify and reword as necessary. Once done, come back to this window.
      EOF
    )

    get("Hit enter when you are ready to proceed...")
  end

  File.read(TMP_LOG_FILE).split("\n")
end

def get_upgrade_guide_path(last_version, new_version)
  input = get("Does this release need an upgrade guide?", ["y", "n"])

  if input == "y"
    guide_name = "from_v#{last_version.major}.#{last_version.minor}_to_v#{new_version.major}.#{new_version.minor}"
    guide_path = "#{UPGRADE_GUIDES_DIR}/#{guide_name}.md"

    if !File.exists?(guide_path)
      loop do
        say(
          <<~EOF
          Please place your upgrade guide in the follow path:

            #{guide_path}

          EOF
        )

        get("Hit enter when you are ready to proceed...")
        
        if File.exists?(guide_path)
          return guide_path
        end

        invalid("You did not add the upgrade guide")
      end
    end
  end

  nil
end

def require_clean_branch!
  files = `git diff-index --name-only HEAD --`.strip

  if files != ""
    error!("Your current branch is not clean. Please commit any pending changes before proceeding.")
  end

  true
end

def require_master_branch!
  branch = `git rev-parse --abbrev-ref HEAD`.chomp

  if branch != "master"
    error!("You must be on the master branch to release.")
  end

  true
end

def save_release_notes!(release)
  templates = Templates.new

  # Create the image
  svg_source = templates.render_hero_svg(release)
  path = "#{DOCS_DIR}/assets/v#{release.version}.svg"
  File.open(path, "w+") { |file| file.write(svg_source) }

  # Create the release notes
  release_notes_source = templates.render_summary(release)
  path = "#{RELEASE_NOTES_DIR}/by-version/#{release.version}.md"
  File.open(path, "w+") { |file| file.write(release_notes_source) }

  words =
    <<~EOF
    Release notes successfully created and placed at:

      #{path}

    Does everything look good? Typing 'y' will commit and tag these changes.
    EOF

  if get(words, ["y", "n"]) == "n"
    error!("Please modify the staged commits file and rerun this command.")
  end
end

#
# Execute
#

puts <<-EOF
                                    __   __  __  
                                    \\ \\ / / / /
                                     \\ V / / /
                                      \\_/  \\/

                                    V E C T O R
                                      Release
#{SEPARATOR}
EOF

#require_master_branch!()
#require_clean_branch!()
new_version = get_new_version()
commit_lines = get_commit_lines("#{LAST_TAG}...#{LAST_COMMIT}")
upgrade_guide_path = get_upgrade_guide_path(LAST_VERSION, new_version)
commits = Commit.all!(commit_lines)
release = Release.new(LAST_VERSION, LAST_TAG, LAST_COMMIT, new_version, commits, upgrade_guide_path)

save_release_notes!(release)

`git add . -A`
`git commit -am 'Prepare v#{release.version} release'`
`git tag v#{release.version}`
`git push`

# get last tag
# get commits
# parse commits
# prepare summary
# add placeholder for human input
# wait for changes to be made
# verify that placeholder was removed
# 