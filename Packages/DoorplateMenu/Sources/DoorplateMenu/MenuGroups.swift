import DoorplateCore
import Foundation

/// One menu position: a single server row, or a group of two or more servers of one project
/// (spec 8.3). Grouping is display only; Core's sections, order and stop rules are unchanged.
public enum MenuGroup: Equatable, Sendable {
  case single(ServerEntry)
  case group(key: String, name: String, branch: String?, entries: [ServerEntry])
}

public enum MenuGroups {
  /// Groups the rows of one section. App rows group by repository root (else their project
  /// folder), Docker rows by Compose working folder; rows without a key stay single. A group
  /// takes the position of its first row, and rows keep their order inside it.
  public static func group(_ entries: [ServerEntry]) -> [MenuGroup] {
    var members: [String: [ServerEntry]] = [:]
    for entry in entries {
      if let key = key(entry) { members[key, default: []].append(entry) }
    }
    var placed: Set<String> = []
    var result: [MenuGroup] = []
    for entry in entries {
      guard let key = key(entry), let rows = members[key], rows.count > 1 else {
        result.append(.single(entry))
        continue
      }
      guard placed.insert(key).inserted else { continue }
      let branch = entry.section == .app ? rows.compactMap(\.branch).first : nil
      result.append(
        .group(
          key: key, name: URL(fileURLWithPath: key).lastPathComponent, branch: branch,
          entries: rows))
    }
    return result
  }

  static func key(_ entry: ServerEntry) -> String? {
    switch entry.section {
    case .app: return entry.repositoryRoot ?? entry.directory
    case .docker: return entry.directory
    default: return nil
    }
  }
}
