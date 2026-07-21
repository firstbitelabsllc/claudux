# Content Protection

Claudux protects sensitive, manually curated, or work-in-progress content from AI modification.

## Protection Philosophy

**Principle**: AI should enhance documentation, not overwrite human expertise.

**Approach**: Several layers keep critical content untouched while updates continue elsewhere.

## Skip Markers

### Inline Protection

Protect specific sections within files using language-appropriate skip markers:

**Markdown files:**
```markdown
<!-- skip -->
## Sensitive Configuration Details

This section contains confidential setup instructions
that should not be automatically modified.

### Internal API Keys
- Production key: [manual setup required]
- Staging key: [contact devops]
<!-- /skip -->
```

**JavaScript/TypeScript:**
```javascript
// skip
const INTERNAL_CONFIG = {
  // This configuration is manually maintained
  // and should not be auto-updated
  secretEndpoint: "internal.company.com"
};
// /skip
```

**Python:**
```python
# skip
# This function handles legacy authentication 
# Keep unchanged for backward compatibility
def legacy_auth_handler():
    pass
# /skip
```

**Swift:**
```swift
// skip
// Core authentication logic - manually maintained
class AuthManager {
    // Implementation details preserved
}
// /skip
```

### Supported Languages

| Language | Start Marker | End Marker |
|----------|--------------|------------|
| Markdown | `<!-- skip -->` | `<!-- /skip -->` |
| JavaScript/TypeScript | `// skip` | `// /skip -->` |
| Python | `# skip` | `# /skip` |
| Swift | `// skip` | `// /skip -->` |
| Go | `// skip` | `// /skip -->` |
| Rust | `// skip` | `// /skip -->` |
| Java/C++ | `// skip` | `// /skip -->` |

## Path-Based Protection

### Automatically Protected Directories

Claudux never modifies content in these directories:

```
📁 Protected Paths:
├── notes/              # Personal notes and drafts
├── private/            # Confidential documentation  
├── .git/               # Version control data
├── node_modules/       # Dependencies
├── vendor/             # Third-party code
├── target/build/dist/  # Build artifacts
```

### Protected File Patterns

Files matching these patterns are never modified:

```
🔒 Protected Files:
*.env          # Environment configuration
*.key, *.pem   # Cryptographic keys
*.p12          # Certificates  
*.keystore     # Java keystores
```

### Custom Path Protection

Configure additional protected paths in your project's content protection settings.

## Work-in-Progress Protection

### Draft Documentation

Protect documentation that's actively being written:

```markdown
<!-- skip -->
# 🚧 Work in Progress: New Feature Documentation

This section is actively being written and should not
be modified until complete.

## Authentication Flow v2
[Draft content being written by Sarah]
<!-- /skip -->
```

### Collaborative Workflows

Protect content being edited by team members:

```markdown
<!-- skip -->
<!-- 
ASSIGNED TO: John Doe
DUE DATE: 2025-09-15
STATUS: In Review

This API documentation is being updated as part 
of the v3.0 release cycle.
-->
## Enterprise API Documentation
[Content under active development]
<!-- /skip -->
```

## Configuration-Based Protection

### Project-Level Settings

Configure protection in `claudux.json`:

```json
{
  "project": {
    "name": "My Project",
    "type": "nodejs"
  },
  "protection": {
    "directories": ["internal/", "drafts/"],
    "files": ["*.private.md", "team-notes.md"],
    "patterns": ["*-wip-*"]
  }
}
```

### Git Integration

Use git patterns for protection:

```bash
# .gitignore patterns extend to documentation protection
echo "internal-docs/" >> .gitignore
echo "*.secret.md" >> .gitignore
```

## Protection Verification

### Skip Marker Detection

Claudux validates protection markers during generation:

```bash
🛡️ Protection Analysis:
✅ Found 3 skip sections in docs/api/internal.md
✅ Protected directory: notes/ (12 files)  
✅ Protected files: 4 files matching *.env pattern
ℹ️  Total protected content: 156 lines across 8 files
```

### Protection Reporting

After generation, claudux reports what was protected:

```bash
📋 Protection Summary:
🛡️ Protected content preserved:
   • docs/internal/secrets.md (skip markers)
   • notes/ directory (5 files)
   • config.env (file pattern)

📝 Content updated:
   • docs/guide/setup.md (outside protected sections)
   • docs/api/public.md (no protection markers)
```

## Best Practices

### 1. Granular Protection

Protect only what needs protection:

```markdown
## Public API Documentation

This section documents our public API endpoints.

<!-- skip -->  
### Internal Debugging Endpoints
These are for development use only...
<!-- /skip -->

## Authentication Flow

Standard OAuth 2.0 implementation...
```

### 2. Clear Boundaries

Use descriptive comments explaining why content is protected:

```markdown
<!-- skip -->
<!-- 
PROTECTED: Contains production credentials and internal URLs
Last updated: 2025-08-15 by Security Team
Next review: 2025-09-15
-->
## Production Deployment Checklist
<!-- /skip -->
```

### 3. Version Control Integration

Commit protection markers for team-wide consistency:

```bash
git add docs/internal.md  # Commit skip markers
git commit -m "Add protection markers for sensitive documentation"
```

### 4. Periodic Review

Regularly review protected content:

```bash
# Find all skip markers across documentation
grep -r "skip" docs/ --include="*.md"

# Review if protection is still needed
claudux update -m "Review and update content protection markers"
```

## Protection Override

### Emergency Updates

When protected content needs updating:

```bash
# Temporarily remove skip markers, update, then re-add
claudux update -m "Update protected section X after removing skip markers"
```

### Selective Protection Removal

Remove protection from specific sections:

```markdown
<!-- Previously protected section now ready for AI updates -->
## Configuration Guide
This section is now stable and can be automatically maintained.
```

## Protection Implementation

Claudux implements protection through:

1. **Pre-processing scan**: Identifies all protection markers before AI analysis
2. **Content isolation**: Protected sections are excluded from AI context  
3. **Post-processing merge**: Protected content is merged back after generation
4. **Validation**: Ensures protection markers remain intact

This multi-layer approach guarantees that protected content remains completely untouched during the documentation generation process.