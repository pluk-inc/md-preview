---
name: changelog-maintenance
description: Maintain a clear and informative changelog for software releases. Use when documenting version changes, tracking features, or communicating updates to users. Always identifies external contributors from git/GitHub and credits them with @username tags. Handles semantic versioning, changelog formats, and release notes.
metadata:
  tags: changelog, release-notes, versioning, semantic-versioning, documentation, contributors
  platforms: Claude, ChatGPT, Gemini
---

# Changelog Maintenance

## When to use this skill

- **Before release**: organize changes before shipping a version
- **Continuous**: update whenever significant changes occur
- **Migration guide**: document breaking changes

## Instructions

### Step 0: Identify contributors (REQUIRED — do this first)

**Always** check who contributed before drafting an entry. Skipping this step is a defect.

1. Determine the previous-release tag/commit. Either parse it from `CHANGELOG.md` (the heading just below the new version) or ask the user.
2. List commit authors and merged PR authors in the range:

   ```bash
   # Authors of all commits in the release range
   git log --format='%h %an <%ae> %s' <prev>..HEAD

   # Merged PRs in the range (if a GitHub remote is configured)
   gh pr list --state merged --limit 50 \
     --json number,title,author,mergedAt \
     --search "merged:>=<prev-merge-date>"
   ```

3. Identify the maintainer(s) — usually the current `git config user.email` / repo owner — and treat everyone else as an **external contributor** that MUST be credited by GitHub `@username`.
4. For PRs that close an issue authored by someone other than the PR author (e.g. `Closes #33`), inspect the issue with `gh issue view <n> --json author` and credit the **reporter** as well.
5. Resolve every contributor's GitHub `login` (the `@handle`). If a commit author's email doesn't map to a GitHub login, look up the merged PR via `gh pr list --search "<commit-sha>"` and use `author.login` from there. Never invent a handle.

If the result is "maintainer-only", omit the Contributors block. If there is at least one external contributor or external bug reporter, you MUST include the Contributors block from Step 1.

### Step 1: Keep a Changelog format

**CHANGELOG.md**:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- New user profile customization options
- Dark mode support

### Changed

- Improved performance of search feature

### Fixed

- Bug in password reset email

## [1.2.0] - 2025-01-15

### Added

- Two-factor authentication (2FA)
- Export user data feature (GDPR compliance)
- API rate limiting
- Webhook support for order events

### Changed

- Updated UI design for dashboard
- Improved email templates
- Database query optimization (40% faster)

### Deprecated

- `GET /api/v1/users/list` (use `GET /api/v2/users` instead)

### Removed

- Legacy authentication method (Basic Auth)

### Fixed

- Memory leak in background job processor
- CORS issue with Safari browser
- Timezone bug in date picker

### Security

- Updated dependencies (fixes CVE-2024-12345)
- Implemented CSRF protection
- Added helmet.js security headers

### Contributors

Thanks to the external contributors who shipped in this release:

- [@octocat](https://github.com/octocat) — webhook support for order events ([#142](https://github.com/username/repo/pull/142))
- [@hubot](https://github.com/hubot) — reported the password-reset email bug ([#138](https://github.com/username/repo/issues/138))

## [1.1.2] - 2025-01-08

### Fixed

- Critical bug in payment processing
- Session timeout issue

## [1.1.0] - 2024-12-20

### Added

- User profile pictures
- Email notifications
- Search functionality

### Changed

- Redesigned login page
- Improved mobile responsiveness

## [1.0.0] - 2024-12-01

Initial release

### Added

- User registration and authentication
- Basic profile management
- Product catalog
- Shopping cart
- Order management

[Unreleased]: https://github.com/username/repo/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/username/repo/compare/v1.1.2...v1.2.0
[1.1.2]: https://github.com/username/repo/compare/v1.1.0...v1.1.2
[1.1.0]: https://github.com/username/repo/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/username/repo/releases/tag/v1.0.0
```

### Step 2: Semantic Versioning

**Version number**: `MAJOR.MINOR.PATCH`

```
Given a version number MAJOR.MINOR.PATCH, increment:

MAJOR (1.0.0 → 2.0.0): Breaking changes
  - API changes break existing code
  - Example: adding required parameters, changing response structure

MINOR (1.1.0 → 1.2.0): Backward-compatible features
  - Add new features
  - Existing functionality continues to work
  - Example: new API endpoints, optional parameters

PATCH (1.1.1 → 1.1.2): Backward-compatible bug fixes
  - Bug fixes
  - Security patches
  - Example: fixing memory leaks, fixing typos
```

**Examples**:

- `1.0.0` → `1.0.1`: bug fix
- `1.0.1` → `1.1.0`: new feature
- `1.1.0` → `2.0.0`: Breaking change

### Step 3: Release Notes (user-friendly)

```markdown
# Release Notes v1.2.0

**Released**: January 15, 2025

## 🎉 What's New

### Two-Factor Authentication

You can now enable 2FA for enhanced security. Go to Settings > Security to set it up.

![2FA Setup](https://example.com/images/2fa.png)

### Export Your Data

We've added the ability to export all your data in JSON format. Perfect for backing up or migrating your account.

## ✨ Improvements

- **Faster Search**: Search is now 40% faster thanks to database optimizations
- **Better Emails**: Redesigned email templates for a cleaner look
- **Dashboard Refresh**: Updated UI with modern design

## 🐛 Bug Fixes

- Fixed a bug where password reset emails weren't being sent
- Resolved timezone issues in the date picker
- Fixed memory leak in background jobs

## ⚠️ Breaking Changes

If you're using our API:

- **Removed**: Basic Authentication is no longer supported

  - **Migration**: Use JWT tokens instead (see [Auth Guide](docs/auth.md))

- **Deprecated**: `GET /api/v1/users/list`
  - **Migration**: Use `GET /api/v2/users` with pagination

## 🔒 Security

- Updated all dependencies to latest versions
- Added CSRF protection to all forms
- Implemented security headers with helmet.js

## 📝 Full Changelog

See [CHANGELOG.md](CHANGELOG.md) for complete details.

---

**Upgrade Instructions**: [docs/upgrade-to-v1.2.md](docs/upgrade-to-v1.2.md)
```

### Step 4: Breaking Changes migration guide

```markdown
# Migration Guide: v1.x to v2.0

## Breaking Changes

### 1. Authentication Method Changed

**Before** (v1.x):
\`\`\`javascript
fetch('/api/users', {
headers: {
'Authorization': 'Basic ' + btoa(username + ':' + password)
}
});
\`\`\`

**After** (v2.0):
\`\`\`javascript
// 1. Get JWT token
const { accessToken } = await fetch('/api/auth/login', {
method: 'POST',
body: JSON.stringify({ email, password })
}).then(r => r.json());

// 2. Use token
fetch('/api/users', {
headers: {
'Authorization': 'Bearer ' + accessToken
}
});
\`\`\`

### 2. User List API Response Format

**Before** (v1.x):
\`\`\`json
{
"users": [...]
}
\`\`\`

**After** (v2.0):
\`\`\`json
{
"data": [...],
"pagination": {
"page": 1,
"limit": 20,
"total": 100
}
}
\`\`\`

**Migration**:
\`\`\`javascript
// v1.x
const users = response.users;

// v2.0
const users = response.data;
\`\`\`

## Deprecation Timeline

- v2.0 (Jan 2025): Basic Auth marked as deprecated
- v2.1 (Feb 2025): Warning logs for Basic Auth usage
- v2.2 (Mar 2025): Basic Auth removed
```

## Output format

```
CHANGELOG.md             # Developer-facing detailed log
RELEASES.md              # User-facing release notes
docs/migration/
  ├── v1-to-v2.md        # Migration guide
  └── v2-to-v3.md
```

## Constraints

### Required rules (MUST)

1. **Reverse chronological**: latest version at the top
2. **Include dates**: ISO 8601 format (YYYY-MM-DD)
3. **Categorize entries**: Added, Changed, Fixed, etc.
4. **Identify and credit external contributors**: every release entry MUST be preceded by the Step 0 contributor check (`git log` + `gh pr list` + issue-reporter lookup for closed issues). When any non-maintainer contributed code or reported a fixed bug, a `### Contributors` block with `[@handle](https://github.com/handle)` GitHub-tag links and the relevant PR/issue numbers MUST be added. Resolve handles from real GitHub data — never invent them.

### Prohibited items (MUST NOT)

1. **No copying Git logs**: write from the user's perspective
2. **Vague wording**: "Bug fixes", "Performance improvements" (be specific)
3. **No silent contributor omission**: do not ship a release entry without running the Step 0 check, even if the user didn't ask for credits explicitly. If the check returns maintainer-only, that is fine — but it must have been run.

## Best practices

1. **Keep a Changelog**: follow the standard format
2. **Semantic Versioning**: consistent version management
3. **Breaking Changes**: provide a migration guide

## References

- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)

## Metadata

### Version

- **Current version**: 1.0.0
- **Last updated**: 2025-01-01
- **Compatible platforms**: Claude, ChatGPT, Gemini

### Tags

`#changelog` `#release-notes` `#versioning` `#semantic-versioning` `#documentation`

## Examples

### Example 1: Basic usage

<!-- Add example content here -->

### Example 2: Advanced usage

<!-- Add advanced example content here -->
