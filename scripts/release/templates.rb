class Templates
  include ActionView::Helpers::NumberHelper

  def pluralize(count, word)
    count != 1 ? "#{count} #{word.pluralize}" : "#{count} #{word}"
  end

  def render_category(category, type_name)
    renderer = build_renderer("_category.md")
    renderer.result(binding).strip
  end

  def render_commit(commit)
    renderer = build_renderer("_commit.md")
    renderer.result(binding).strip.gsub("\n", "")
  end

  def render_commits_list(commits)
    renderer = build_renderer("_commits_list.md")
    renderer.result(binding).strip
  end

  def render_grouped_commits(commits, type_name, categories: true)
    commits = sort_commits(commits)
    renderer = build_renderer("_grouped_commits.md")
    renderer.result(binding).strip
  end

  def render_hero_svg(release)
    renderer = build_renderer("hero.svg")
    renderer.result(binding).strip
  end

  def render_scope(scope)
    text =
      if scope.existing_component?
        "`#{scope.component_name}` #{scope.component_type}"
      else
         scope.name
      end

    if scope.short_link
      "[#{text}][#{scope.short_link}]"
    else
      text
    end
  end

  def render_summary(release)
    renderer = build_renderer("summary.md")
    renderer.result(binding).strip
  end

  def render_toc_item(commits, type_name, categories: true)
    commits = sort_commits(commits)
    renderer = build_renderer("_toc_item.md")
    renderer.result(binding).strip.gsub(/,$/, "")
  end

  def summary(release)
    parts = []

    if release.new_features.any?
      parts << pluralize(release.new_features.size, "new feature")
    end

    if release.enhancements.any?
      parts << pluralize(release.enhancements.size, "enhancement")
    end

    if release.bug_fixes.any?
      parts << pluralize(release.bug_fixes.size, "bug fix")
    end

    parts.join(", ")
  end

  private
    def build_renderer(template)
      template_path = "#{Dir.pwd}/templates/#{template}.erb"
      template = File.read(template_path)
      ERB.new(template, nil, '-')
    end

    def sort_commits(commits)
      commits.sort_by do |commit|
        [commit.scope.category, commit.scope.name, commit.date]
      end
    end
end