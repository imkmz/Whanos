# Job DSL Dynamic Job Creation - Troubleshooting Guide

## Problem Summary
Creating Jenkins jobs dynamically using Job DSL with nested shell scripts requires triple-level variable escaping. This document explains the solution to the 4-hour debugging session on 2025-11-02.

## The Challenge

### Goal
Create a `link-project` job that:
1. Takes repository parameters (URL, name, branch)
2. Uses Job DSL to generate a new freestyle job
3. Generated job contains shell script with variable interpolation
4. Shell script uses both Jenkins parameters AND bash variables

### The Issue
Variables need to pass through 3 processing layers:
1. **Groovy DSL** (reading jobs.groovy)
2. **Job DSL** (generating Jenkins XML)
3. **Bash** (executing shell script)

Each layer interprets `$` differently, causing variables to be evaluated too early or not at all.

## Failed Approaches

### Attempt 1: Direct Variable Reference
```groovy
text('''
    shell("""
        IMAGE_NAME="${PROJECT_NAME}:$BUILD_NUMBER"
    """)
''')
```
**Result**: `$BUILD_NUMBER` evaluated by Groovy → empty string  
**Error**: `invalid tag "project-name:": invalid reference format`

### Attempt 2: Single Backslash Escape
```groovy
text('''
    shell("""
        IMAGE_NAME="${PROJECT_NAME}:\$BUILD_NUMBER"
    """)
''')
```
**Result**: Job DSL sees `\$BUILD_NUMBER` as regex backreference  
**Error**: `invalid tag "project-name:\1": invalid reference format`

### Attempt 3: Double Backslash
```groovy
text('''
    shell("""
        IMAGE_NAME="${PROJECT_NAME}:\\$BUILD_NUMBER"
    """)
''')
```
**Result**: Still interpreted as backreference in some contexts  
**Error**: Inconsistent behavior

### Attempt 4: Four Backslashes
```groovy
text('''
    shell("""
        IMAGE_NAME="${PROJECT_NAME}:\\\\$BUILD_NUMBER"
    """)
''')
```
**Result**: Too many escapes, literal `\\$` in bash  
**Error**: `invalid tag "project-name:\\2": invalid reference format`

### Attempt 5: Quote Concatenation
```groovy
text("""
    shell('''
        PROJECT_NAME="''' + '${PROJECT_NAME}' + '''"
    ''')
""")
```
**Result**: Groovy parser error - can't concatenate inside string literal  
**Error**: `illegal string body character after dollar sign`

## Working Solution

### The Pattern
```groovy
text('''                                      // Outer: Literal for Job DSL
folder('Projects')

freeStyleJob("Projects/${PROJECT_NAME}") {   // Groovy interpolation
    steps {
        shell("""#!/bin/bash                 // Inner: Shell script
            IMAGE_NAME="${PROJECT_NAME}:\\$BUILD_NUMBER"  // Mixed
            docker build -t \\$IMAGE_NAME .              // Bash only
        """)
    }
}
''')
```

### Key Rules

#### 1. Outer String: Triple Single Quotes `'''`
- Job DSL script is literal text
- Groovy interpolates `${VARIABLE}` for job parameters
- Used for variables from `link-project` parameters

#### 2. Inner String: Triple Double Quotes `"""`
- Shell script passed to Jenkins
- Allows mixed Groovy + bash variables
- Groovy processes first, then bash

#### 3. Variable Escaping

| Context | Syntax | Result | Use Case |
|---------|--------|--------|----------|
| Groovy param | `${PROJECT_NAME}` | Interpolated by Groovy | Job parameters |
| Jenkins env | `\\$BUILD_NUMBER` | `$BUILD_NUMBER` in bash | Jenkins variables |
| Bash variable | `\\$IMAGE_NAME` | `$IMAGE_NAME` in bash | Shell variables |

### Complete Working Example
```groovy
freeStyleJob('link-project') {
    parameters {
        stringParam('REPOSITORY_URL', '', 'Git repository URL')
        stringParam('PROJECT_NAME', '', 'Project name')
        stringParam('BRANCH', 'main', 'Branch to monitor')
    }
    steps {
        dsl {
            text('''
folder('Projects')

freeStyleJob("Projects/${PROJECT_NAME}") {
    description("Whanos project: ${PROJECT_NAME}")
    
    scm {
        git {
            remote {
                url("${REPOSITORY_URL}")
            }
            branch("*/${BRANCH}")
        }
    }
    
    steps {
        shell("""#!/bin/bash
set -e

echo "[INFO] Starting build for ${PROJECT_NAME}"
echo "[DETECT] Detecting language"

LANGUAGE="unknown"
if [ -f "requirements.txt" ]; then
    LANGUAGE="python"
fi

echo "[LANGUAGE] Detected: \\$LANGUAGE"

IMAGE_NAME="${PROJECT_NAME}:\\$BUILD_NUMBER"

docker build -t \\$IMAGE_NAME .
""")
    }
}
            '''.stripIndent())
        }
    }
}
```

## Debugging Checklist

When job creation fails:

### 1. Check Quote Matching
```bash
# Count quotes in jobs.groovy
grep -o "'''" jenkins/jobs.groovy | wc -l  # Must be even
grep -o '"""' jenkins/jobs.groovy | wc -l  # Must be even
```

### 2. Test Variable Expansion
Add debug echos:
```bash
echo "DEBUG: PROJECT_NAME=${PROJECT_NAME}"    # Should show actual name
echo "DEBUG: BUILD_NUMBER=\\$BUILD_NUMBER"   # Should show number at runtime
```

### 3. Check Error Messages
| Error | Cause | Fix |
|-------|-------|-----|
| `No such property: VARIABLE` | Groovy saw bash variable | Add `\\` escape |
| `illegal string body character` | Wrong quote type | Use `'''` outer, `"""` inner |
| `invalid tag ":1"` | Backreference interpreted | Use `\\$` not `\$` |
| `invalid tag ""` | Empty variable | Check Groovy interpolation |

### 4. Verify Job Creation
```bash
# After link-project runs, check Jenkins workspace
docker exec whanos-jenkins ls -la /var/jenkins_home/jobs/Projects/jobs/

# Should show new job directory
```

### 5. Volume Persistence Issue
If old config persists:
```bash
# Nuclear option - full rebuild
docker-compose down
docker volume rm jenkins_jenkins_home
docker-compose build --no-cache
docker-compose up -d
sleep 50
```

## Why This Is Complicated

### The Three Processing Stages

```
jobs.groovy file
    ↓
1. Groovy reads file
   - Processes ${PROJECT_NAME} in ''' strings
   - Creates Job DSL script
    ↓
2. Job DSL plugin runs
   - Parses """ strings
   - Interprets \$ and \\$ escapes
   - Generates Jenkins XML
    ↓
3. Jenkins executes job
   - Bash shell processes script
   - Evaluates $VARIABLE
   - Runs commands
```

### Escape Count Examples

| Original | After Groovy | After Job DSL | In Bash |
|----------|-------------|---------------|---------|
| `${VAR}` | `value` | `value` | `value` |
| `\\$VAR` | `\$VAR` | `$VAR` | (evaluated) |
| `\\\\$VAR` | `\\$VAR` | `\$VAR` | `$VAR` (literal) |

## Best Practices

### 1. Separate Concerns
```groovy
// Groovy parameters (from link-project)
"${PROJECT_NAME}"    // ✓ Use directly

// Jenkins environment variables
"\\$BUILD_NUMBER"    // ✓ Double backslash

// Bash variables
"\\$LANGUAGE"        // ✓ Double backslash
```

### 2. Test Incrementally
1. Start with simple job (no variables)
2. Add Groovy interpolation
3. Add Jenkins variables
4. Add bash variables

### 3. Use Consistent Patterns
Don't mix escape styles within same script.

### 4. Document Tricky Parts
```groovy
// NOTE: \\$ required because variable passes through Job DSL
IMAGE_NAME="\\$BUILD_NUMBER"
```

## References
- [Job DSL API](https://jenkinsci.github.io/job-dsl-plugin/)
- [Groovy String Interpolation](https://groovy-lang.org/syntax.html#_string_interpolation)
- [Jenkins Environment Variables](https://wiki.jenkins.io/display/JENKINS/Building+a+software+project#Buildingasoftwareproject-belowJenkinsSetEnvironmentVariables)

## Lessons Learned
1. **Quote type matters**: `'''` vs `"""` changes interpolation behavior
2. **Count backslashes**: Each processing layer consumes one `\`
3. **Volume persistence**: Old configs override new DSL
4. **Test syntax locally**: Groovy console can validate before deployment
5. **Nuclear rebuild**: When in doubt, wipe volume and rebuild
