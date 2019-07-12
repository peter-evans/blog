workflow "Check markdown links" {
  on = "push"
  resolves = ["Link Checker"]
}

action "Link Checker" {
  uses = "peter-evans/link-checker@v1.0.0"
  args = "-v -d static -r content"
}
