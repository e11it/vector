require "json"

class Commit
  TYPES = ["chore", "docs", "feat", "fix", "improvement", "perf"]
  TYPES_THAT_REQUIRE_SCOPES = ["feat", "improvement", "fix"]
  NEW_FEATURE_CATEGORIES = ["new source", "new transform", "new sink"]

  class << self
    def all!(commit_lines)
      commits =
        commit_lines.collect do |commit_line|
          attributes = parse!(commit_line)
          new(attributes)
        end

      commits.compact
    end

    def parse!(commit_line)
      attributes = {}

      # Parse the raw commit line
      commit_line_attributes = parse_commit_line!(commit_line)
      attributes.merge!(commit_line_attributes)

      # Parse the convention commit message
      commit_message_attributes = parse_commit_message!(attributes.fetch("message"))
      attributes.merge!(commit_message_attributes)

      attributes
    end

    def valid?(message)
      parse(message).any?
    end

    private
      def parse_commit_line!(message)
        message_parts = message.split("\t")

        {
          "commit" =>  message_parts.fetch(0),
          "message" => message_parts.fetch(1),
          "author" => message_parts.fetch(2),
          "date" => message_parts.fetch(3)
        }
      end

      def parse_commit_message!(description)
        match = description.match(/^(?<type>[a-z]*)(?<breaking_change>!)?(\((?<scope>[a-z0-9_ ]*)\))?: (?<description>.*?)( \(#(?<pr_number>[0-9]*)\))?$/)

        if match.nil?
          raise <<~EOF
          Commit message does not conform to the conventional commit format.
          
          Unable to parse at all!

            #{description}

          Please correct and retry.
          EOF
        end

        attributes =
          {
            "type" => match[:type],
            "breaking_change" => !match[:breaking_change].nil?,
            "scope" => match[:scope],
            "description" => match[:description],
            "pr_number" => match[:pr_number]
          }

        type = attributes.fetch("type")
        scope = attributes.fetch("scope")

        if !type.nil? && !TYPES.include?(type)
          raise <<~EOF
          Commit has an invalid type!

          The type must be one of #{TYPES.inspect}.

            #{type.inspect}
          
          Please correct and retry.
          EOF
        end

        if TYPES_THAT_REQUIRE_SCOPES.include?(type) && scope.nil?
          raise <<~EOF
          Commit does not have a scope!

          A scope is required for commits of type #{TYPES_THAT_REQUIRE_SCOPES.inspect}.

            #{description}

          Please correct and retry.
          EOF
        end

        attributes
      end
  end

  attr_reader :author,
    :breaking_change,
    :commit,
    :date,
    :deletions_count,
    :description,
    :files_count,
    :insertions_count,
    :message,
    :pr_number,
    :scope,
    :type

  def initialize(attributes)
    @author = attributes.fetch("author")
    @breaking_change = attributes.fetch("breaking_change")
    @scope = Scope.new(attributes["scope"] || "core")
    @commit = attributes.fetch("commit")
    @date = attributes.fetch("date")
    @description = attributes.fetch("description")
    @message = attributes.fetch("message")
    @pr_number = attributes["pr_number"]
    @type = attributes.fetch("type")

    stats_line = `git show --shortstat --oneline #{@commit}`.split("\n").last
    stats_attributes = parse_stats(stats_line)

    @deletions_count = stats_attributes["deletions_count"] || 0
    @files_count = stats_attributes.fetch("files_count")
    @insertions_count = stats_attributes["insertions_count"] || 0
  end

  def breaking_change?
    @breaking_change == true
  end

  def bug_fix?
    type == "fix"
  end

  def category
    scope.category
  end

  def chore?
    type == "chore"
  end

  def commit_short
    @commit_short ||= commit.truncate(7, omission: "")
  end

  def component_name
    return @component_name if defined?(@component_name)

    @component_name =
      if new_feature?
        match =  description.match(/`?(?<name>[a-zA-Z_]*)`? (source|transform|sink)/)
        
        if !match.nil? && !match[:name].nil?
          match[:name].downcase
        else
          nil
        end
      else
        scope.component_name
      end
  end

  def component_name!
    if component_name.nil?
      raise "Component name could not be found in commit: #{message}"
    end

    component_name
  end

  def component_type
    scope.component_type
  end

  def component_type!
    if component_type.nil?
      raise "Component type could not be found in commit: #{message}"
    end

    component_type
  end

  def doc_update?
    type == "docs"
  end

  def enhancement?
    type == "improvement"
  end

  def new_component?
    new_feature? && !component_name.nil?
  end

  def new_feature?
    type == "feat"
  end

  def performance_improvement?
    type == "perf"
  end

  def sink?
    component_type == "sink"
  end

  def source?
    component_type == "source"
  end

  def transform?
    component_type == "transform"
  end

  private
    def parse_stats(stats)
      attributes = {}

      stats.split(", ").each do |stats_part|
        stats_part.strip!

        key =
          case stats_part
          when /insertions?/
            "insertions_count"
          when /deletions?/
            "deletions_count"
          when /files? changed/
            "files_count"
          else
            raise "Invalid commit stat: #{stats_part}"
          end

        count = stats_part.match(/^(?<count>[0-9]*) /)[:count].to_i
        attributes[key] = count
      end

      attributes
    end
end