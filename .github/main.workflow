workflow "Check markdown links" {
  resolves = ["Create Issue From File"]
  on = "schedule(0 0 1 * *)"
}

action "Link Checker" {
  uses = "peter-evans/link-checker@v1.0.0"
  args = "-v -d static -r content"
}

action "Create Issue From File" {
  needs = "Link Checker"
  uses = "peter-evans/create-issue-from-file@v1.0.1"
  secrets = ["GITHUB_TOKEN"]
  env = {
    ISSUE_TITLE = "Link Checker Report"
    ISSUE_CONTENT_FILEPATH = "./link-checker/out.md"
    ISSUE_LABELS = "report, automated issue"
    ISSUE_ASSIGNEES = "peter-evans"
  }
}
