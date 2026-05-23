# Template System

Claudux uses a flexible template system to generate project-appropriate documentation structures based on project type and patterns.

## Template Architecture

### Template Hierarchy

Templates are organized by project type with fallback support:

```
lib/templates/
├── generic/config.json          # Universal fallback
├── javascript-project-config.json
├── react-project-config.json    # Extends javascript patterns
├── nextjs-project-config.json   # Extends react patterns  
├── ios-project-config.json      # iOS-specific structure
├── vidux-project-config.json    # Plan-first team-agent repos
├── python-project-config.json
├── rust-project-config.json
└── go-project-config.json
```

### Template Selection Logic

**Selection process** (`lib/docs-generation.sh:24-32`):
1. Try exact project type match: `{type}-project-config.json`
2. Try alternative naming: `{type}-config.json`  
3. Try directory structure: `{type}/config.json`
4. Fall back to: `generic/config.json`

Example for Next.js project:
```bash
PROJECT_TYPE="nextjs"
# Looks for: nextjs-project-config.json ✅
# Falls back to: generic/config.json if not found
```

## Template Configuration Format

### Basic Structure

```json
{
  "project": {
    "name": "Project Name Pattern",
    "type": "project_type", 
    "description": "Default description pattern"
  },
  "ai": {
    "default_model": "sonnet",
    "fast_model": "sonnet",
    "timeout_seconds": 90
  },
  "documentation": {
    "framework": "vitepress",
    "sidebar_structure_guide": { },
    "serve_port": 5173
  },
  "claude_instructions": {
    "focus_areas": [
      "Specific documentation priorities"
    ]
  }
}
```

### Sidebar Structure Guide

Templates define expected navigation hierarchy:

```json
"sidebar_structure_guide": {
  "/": [
    {
      "text": "Getting Started", 
      "items": [
        { "text": "Overview", "link": "/guide/" },
        { "text": "Installation", "link": "/guide/installation" },
        { "text": "Quick Start", "link": "/guide/quickstart" }
      ]
    },
    {
      "text": "User Guide",
      "items": [
        { "text": "Core Features", "link": "/features/" },
        { "text": "Configuration", "link": "/guide/configuration" }
      ]
    }
  ]
}
```

## Project-Specific Templates

### React Template Example

`react-project-config.json` emphasizes component documentation:

```json
{
  "claude_instructions": {
    "focus_areas": [
      "Component API documentation with props and examples",
      "React hooks usage patterns", 
      "State management patterns (Redux, Context)",
      "Testing with React Testing Library",
      "Build and deployment with Vite/Webpack"
    ]
  },
  "documentation": {
    "sidebar_structure_guide": {
      "/": [
        {
          "text": "Components",
          "items": [
            { "text": "Component Library", "link": "/components/" },
            { "text": "Styling Guide", "link": "/components/styling" }
          ]
        }
      ]
    }
  }
}
```

### iOS Template Example

`ios-project-config.json` focuses on app-specific documentation:

```json
{
  "claude_instructions": {
    "focus_areas": [
      "App architecture and SwiftUI patterns",
      "Data persistence (Core Data, SwiftData)",
      "App Store deployment process",
      "Testing with XCTest framework",
      "Dependency management with SPM/CocoaPods"
    ]
  }
}
```

### Vidux Template Example

`vidux-project-config.json` focuses on plan-first team-agent documentation:

```json
{
  "project": {
    "type": "vidux",
    "description": "Plan-first documentation template for repos coordinated through vidux PLAN.md files and team-agent lanes"
  },
  "claude_instructions": {
    "focus_areas": [
      "PLAN.md and projects/*/PLAN.md as source-owned operating state",
      "Team-agent lane handoffs, ownership, and verification gates",
      "Drift Log and Progress sections as append-only evidence, not marketing copy"
    ]
  }
}
```

Detection selects this template when a repo has `vidux.config.json`, or when it has a root `PLAN.md` plus at least one `projects/*/PLAN.md`. Use it for repos where the docs need to explain active agent lanes, plan handoffs, local telemetry, and verification gates without letting the backend rewrite the plan itself.

## Template Customization

### Creating Custom Templates

1. **Copy existing template:**
   ```bash
   cp lib/templates/generic/config.json lib/templates/mytype-project-config.json
   ```

2. **Modify for your project type:**
   ```json
   {
     "project": {
       "type": "mytype",
       "description": "Custom project type documentation"
     },
     "claude_instructions": {
       "focus_areas": [
         "Domain-specific patterns",
         "Framework-specific documentation",
         "Custom deployment processes"
       ]
     }
   }
   ```

3. **Add detection logic:**
   
   Update `lib/project.sh:33-64` to detect your project type:
   ```bash
   detect_project_type() {
       # Add your detection logic
       if [[ -f "myframework.config.js" ]]; then
           echo "mytype"
       # ... existing detection logic
   }
   ```

### Project-Level Override

Override templates with project-specific configuration in `claudux.json`:

```json
{
  "project": {
    "name": "My Custom Project",
    "type": "react"
  },
  "documentation": {
    "custom_sections": ["deployment", "monitoring"],
    "omit_sections": ["examples"]
  },
  "claude_instructions": {
    "focus_areas": [
      "Custom focus area 1",
      "Custom focus area 2"  
    ]
  }
}
```

## Template Preprocessing

### Variable Substitution

Templates support dynamic variable replacement:

**VitePress config template** (`lib/vitepress/config.template.ts`):
```typescript
export default defineConfig({
  title: '{{PROJECT_NAME}}',
  description: '{{PROJECT_DESCRIPTION}}',
  logo: { src: '{{LOGO_PATH}}' },
  // ...
})
```

**Runtime substitution:**
- `{{PROJECT_NAME}}` → Value from `package.json` or `claudux.json`
- `{{PROJECT_DESCRIPTION}}` → Auto-detected or configured description
- `{{LOGO_PATH}}` → Auto-detected logo file or empty if none found

### Conditional Content

Templates can include conditional logic:

```json
{
  "conditional_sections": {
    "if_testing_framework": {
      "jest": ["testing/jest-setup.md"],
      "mocha": ["testing/mocha-setup.md"]
    },
    "if_has_api": {
      "express": ["api/express-routes.md"],
      "fastapi": ["api/fastapi-endpoints.md"]
    }
  }
}
```

## Template Development

### Testing Templates

Test template changes without affecting existing docs:

```bash
# Use specific template for testing
claudux recreate  # Start fresh with template changes
```

### Template Validation

Templates are validated during prompt construction:

```bash
📝 Building prompt for react project...
✅ Template loaded: react-project-config.json
✅ Sidebar structure validated  
✅ Focus areas configured (5 items)
```

**Validation checks:**
- JSON syntax correctness
- Required fields present
- Sidebar structure validity
- Link target reachability

### Contributing Templates

1. **Identify gap**: What project type lacks good documentation structure?
2. **Analyze patterns**: What are the common documentation needs for that type?
3. **Create template**: Follow existing template patterns
4. **Test thoroughly**: Generate docs for multiple projects of that type
5. **Submit PR**: Include template and detection logic updates

## Template Best Practices

### 1. Focus Areas

Define specific, actionable focus areas:

```json
"focus_areas": [
  "Component props and TypeScript interfaces",      // ✅ Specific  
  "Authentication and authorization patterns",      // ✅ Specific
  "Docker deployment configuration"                 // ✅ Specific
]

// Avoid generic focus areas:
"focus_areas": [
  "Write good documentation",                       // ❌ Too generic
  "Document the code"                               // ❌ Not helpful
]
```

### 2. Sidebar Organization

Organize by user journey, not internal code structure:

```json
// ✅ User-focused organization
"sidebar_structure_guide": {
  "/": [
    { "text": "Getting Started", "items": [...] },
    { "text": "Using the API", "items": [...] },  
    { "text": "Deploying", "items": [...] }
  ]
}

// ❌ Code-focused organization  
"sidebar_structure_guide": {
  "/": [
    { "text": "src/ Directory", "items": [...] },
    { "text": "lib/ Directory", "items": [...] }
  ]
}
```

### 3. Progressive Disclosure

Structure information from basic to advanced:

```json
{
  "text": "API Reference",
  "items": [
    { "text": "Quick Start", "link": "/api/" },          // Basic usage
    { "text": "Authentication", "link": "/api/auth" }, // Common need  
    { "text": "Advanced", "link": "/api/advanced" }    // Power users
  ]
}
```

This template system enables claudux to generate documentation that feels native to each project type while maintaining consistency and quality.
