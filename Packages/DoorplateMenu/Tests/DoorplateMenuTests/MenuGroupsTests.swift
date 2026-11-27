import DoorplateCore
import Testing

@testable import DoorplateMenu

struct MenuGroupsTests {
  private func app(
    _ port: UInt16, _ title: String, root: String?, directory: String? = nil, branch: String? = nil
  ) -> ServerEntry {
    entry(
      port: port, title: title, id: "pid:\(port)", pid: Int32(port),
      directory: directory ?? root.map { "\($0)/\(title)" }, root: root, branch: branch)
  }

  @Test func singleProjectsStaySingle() {
    let rows = [
      app(3000, "site", root: "/Users/dev/acme"), app(8080, "shop", root: "/Users/dev/shop"),
    ]
    #expect(MenuGroups.group(rows) == rows.map(MenuGroup.single))
  }

  @Test func twoOrMoreRowsOfOneRepositoryGroupAtTheFirstRow() {
    let site = app(3000, "site", root: "/Users/dev/acme", branch: "main")
    let shop = app(4000, "shop", root: "/Users/dev/shop")
    let web = app(5173, "web", root: "/Users/dev/acme", branch: "main")
    let api = app(8000, "api", root: "/Users/dev/acme", branch: "main")
    #expect(
      MenuGroups.group([site, shop, web, api]) == [
        .group(key: "/Users/dev/acme", name: "acme", branch: "main", entries: [site, web, api]),
        .single(shop),
      ])
  }

  @Test func withoutARepositoryTheProjectFolderIsTheKey() {
    let a = app(3000, "a", root: nil, directory: "/Users/dev/tool")
    let b = app(3001, "b", root: nil, directory: "/Users/dev/tool")
    let loose = app(3002, "c", root: nil, directory: nil)
    #expect(
      MenuGroups.group([a, b, loose]) == [
        .group(key: "/Users/dev/tool", name: "tool", branch: nil, entries: [a, b]), .single(loose),
      ])
  }

  @Test func worktreesGroupSeparately() {
    let main = [
      app(3000, "web", root: "/Users/dev/acme"), app(3001, "api", root: "/Users/dev/acme"),
    ]
    let login = [
      app(4000, "web", root: "/Users/dev/acme-login"),
      app(4001, "api", root: "/Users/dev/acme-login"),
    ]
    let groups = MenuGroups.group(main + login)
    #expect(groups.count == 2)
    guard case .group(_, let name, _, _) = groups.last else {
      Issue.record("expected a group")
      return
    }
    #expect(name == "acme-login")
  }

  @Test func dockerGroupsByComposeFolderWithoutBranch() {
    func container(_ port: UInt16, _ id: String, _ folder: String?) -> ServerEntry {
      entry(
        port: port, title: id, tool: id, section: .docker, id: "docker:\(id)", directory: folder,
        root: nil, branch: "main")
    }
    let db = container(5432, "db", "/Users/dev/acme")
    let redis = container(6379, "redis", "/Users/dev/acme")
    let plain = container(8081, "adminer", nil)
    #expect(
      MenuGroups.group([db, plain, redis]) == [
        .group(key: "/Users/dev/acme", name: "acme", branch: nil, entries: [db, redis]),
        .single(plain),
      ])
  }

  @Test func systemRowsNeverGroup() {
    let rows = [
      entry(port: 5000, section: .system, id: "pid:1", root: "/x"),
      entry(port: 7000, section: .system, id: "pid:2", root: "/x"),
    ]
    #expect(MenuGroups.group(rows) == rows.map(MenuGroup.single))
  }
}
