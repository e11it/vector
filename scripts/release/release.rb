class Release
  attr_reader :commits, :last_version, :last_tag, :last_commit, :upgrade_guide_path, :version

  def initialize(last_version, last_tag, last_commit, version, commits, upgrade_guide_path)
    @last_version = last_version
    @last_tag = last_tag
    @last_commit = last_commit
    @version = version
    @commits = commits
    @upgrade_guide_path = upgrade_guide_path
  end

  def authors
    @authors ||= commits.collect(&:author).uniq.sort
  end

  def breaking_changes
    @breaking_changes ||= commits.select(&:breaking_change?)
  end

  def bug_fixes
    @bug_fixes ||= commits.select(&:bug_fix?)
  end

  def compare_url
    @compare_url ||= "https://github.com/timberio/vector/compare/v#{last_version}...v#{version}"
  end

  def deletions_count
    @deletions_count ||= countable_commits.sum(&:deletions_count)
  end

  def doc_updates
    @doc_updates ||= commits.select(&:doc_update?)
  end

  def enhancements
    @enhancements ||= commits.select(&:enhancement?)
  end

  def files_count
    @files_count ||= countable_commits.sum(&:files_count)
  end

  def insertions_count
    @insertions_count ||= countable_commits.sum(&:insertions_count)
  end

  def new_features
    @new_features ||= commits.select(&:new_feature?)
  end

  def major?
    type == "major"
  end

  def minor?
    type == "minor"
  end

  def patch?
    type == "patch"
  end

  def performance_improvements
    @performance_improvements ||= commits.select(&:performance_improvement?)
  end

  def pre?
    type == "pre"
  end

  def short_link
    @short_link ||= "url.v" + version.to_s.gsub(".", "-")
  end

  def type
    @type ||= last_version.bump_type(version)
  end

  def upgrade_guide?
    !upgrade_guide_path.nil?
  end

  def upgrade_guide_short_link
    @upgrade_guide_short_link ||= "docs." + File.basename(upgrade_guide_path, ".md")
  end

  private
    def countable_commits
      @countable_commits ||= commits.select do |commit|
        !commit.doc_update?
      end
    end
end