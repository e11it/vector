<!--

NOTE!

Your PR title must conform to the conventionalcommits.org spec. We use this
to automatically generate our changelogs and it makes Ben happy :)

Format specification:

  <type>[!]([scope]): <description>

Examples:

  improvement(elasticsearch sink): Add `headers` option for custom request headers
  feat(new sink): Initial `xyz` sink implementation
  fix(file source): Do not panic when file is deleted
  improvement!(kafka source): Drop support for `xyz` option

Types:

  * `feat` - Entirely new features, such as new sources, transforms, and sinks.
  * `improvement` - Improvements to an existing feature.
  * `fix` - Bug fixes.
  * `docs` - Documentation updates/
  * `perf` - Performance improvments.
  * `!` - Suffix any of the above with a `!` to denote a breaking change.

Scopes:

  * Further describes the type.
  * see `.github/semantic.yml` for a list of valid scopes.

---

PSA!

Using Vector? Let us know! Add your company here:

https://github.com/timberio/vector/blob/master/.companies.toml

-->