import Foundation

/// Reads the current branch from git's own files, never by running `git` (spec 5, 7.5).
public enum GitHead {
  /// The HEAD file of the repository rooted at `root`: `.git/HEAD`, or, when `.git` is a file
  /// (`gitdir: <path>` in worktrees and submodules), the HEAD inside that directory.
  public static func headPath(root: String, dotGitFile: String?) -> String {
    let base = URL(fileURLWithPath: root)
    if let dotGitFile, let line = dotGitFile.split(whereSeparator: \.isNewline).first,
      line.hasPrefix("gitdir:")
    {
      let target = line.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
      if !target.isEmpty {
        let directory =
          target.hasPrefix("/")
          ? URL(fileURLWithPath: target) : base.appendingPathComponent(target)
        return directory.appendingPathComponent("HEAD").standardizedFileURL.path
      }
    }
    return base.appendingPathComponent(".git/HEAD").standardizedFileURL.path
  }

  /// The branch named by a HEAD file: `ref: refs/heads/<name>` gives `<name>`, another
  /// `ref:` gives the ref without `refs/`, and a detached commit id gives its first 7 digits.
  public static func branch(fromHead text: String) -> String? {
    guard let line = text.split(whereSeparator: \.isNewline).first else { return nil }
    let head = line.trimmingCharacters(in: .whitespaces)
    if head.hasPrefix("ref:") {
      let ref = head.dropFirst("ref:".count).trimmingCharacters(in: .whitespaces)
      for prefix in ["refs/heads/", "refs/"] where ref.hasPrefix(prefix) {
        let name = String(ref.dropFirst(prefix.count))
        return name.isEmpty ? nil : name
      }
      return nil
    }
    let isHex = head.allSatisfy { $0.isHexDigit }
    // SHA-1 (40) and SHA-256 (64) object ids.
    if isHex, head.count == 40 || head.count == 64 { return String(head.prefix(7)) }
    return nil
  }
}
