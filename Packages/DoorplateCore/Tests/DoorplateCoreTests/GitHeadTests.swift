import DoorplateCore
import Testing

@Suite struct GitHeadTests {
  @Test func branchNames() {
    #expect(GitHead.branch(fromHead: "ref: refs/heads/main\n") == "main")
    #expect(GitHead.branch(fromHead: "ref: refs/heads/feat/login\n") == "feat/login")
    #expect(GitHead.branch(fromHead: "ref:refs/heads/fix\r\n") == "fix")
  }

  @Test func otherRefsDropRefsPrefix() {
    #expect(GitHead.branch(fromHead: "ref: refs/remotes/origin/main\n") == "remotes/origin/main")
    #expect(GitHead.branch(fromHead: "ref: HEAD\n") == nil)
    #expect(GitHead.branch(fromHead: "ref: refs/heads/\n") == nil)
  }

  @Test func detachedHeadShowsShortHash() {
    let sha1 = "3f2a9c1d4e5b6a7980123456789abcdef0123456"
    #expect(GitHead.branch(fromHead: sha1 + "\n") == "3f2a9c1")
    let sha256 = String(repeating: "ab", count: 32)
    #expect(GitHead.branch(fromHead: sha256) == "abababa")
  }

  @Test func garbageHasNoBranch() {
    #expect(GitHead.branch(fromHead: "") == nil)
    #expect(GitHead.branch(fromHead: "\n") == nil)
    #expect(GitHead.branch(fromHead: "3f2a9c1") == nil)
    #expect(GitHead.branch(fromHead: "not a head file") == nil)
  }

  @Test func headPathForRepositoriesAndWorktrees() {
    #expect(
      GitHead.headPath(root: "/Users/dev/shop", dotGitFile: nil) == "/Users/dev/shop/.git/HEAD")
    // A `.git` directory reads as nil; an empty fixture marker is not a gitdir pointer.
    #expect(
      GitHead.headPath(root: "/Users/dev/shop", dotGitFile: "") == "/Users/dev/shop/.git/HEAD")
    #expect(
      GitHead.headPath(
        root: "/Users/dev/shop-login", dotGitFile: "gitdir: /Users/dev/shop/.git/worktrees/login\n")
        == "/Users/dev/shop/.git/worktrees/login/HEAD")
    #expect(
      GitHead.headPath(
        root: "/Users/dev/app/vendor/lib", dotGitFile: "gitdir: ../../.git/modules/lib")
        == "/Users/dev/app/.git/modules/lib/HEAD")
  }
}
