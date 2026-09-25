#!/usr/bin/env python3
"""
PR Change Analyzer

Analyzes git changes between current branch and base branch to generate
comprehensive pull request information including commit analysis, file changes,
and metadata extraction.
"""

import subprocess
import json
import sys
import re
from typing import Dict, List, Optional, Tuple
from collections import Counter


def run_git_command(command: List[str]) -> str:
    """Run a git command and return its output."""
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return ""


def get_current_branch() -> str:
    """Get the current git branch name."""
    return run_git_command(['git', 'rev-parse', '--abbrev-ref', 'HEAD'])


def get_base_branch() -> str:
    """Detect the base branch from git config or default to main/master."""
    # Try to get the tracking branch
    tracking = run_git_command(['git', 'rev-parse', '--abbrev-ref', '@{upstream}'])
    if tracking and '/' in tracking:
        # Extract branch name from remote/branch format; a pushed feature
        # branch tracks itself, which is not a base
        base = tracking.split('/', 1)[1]
        if base != get_current_branch():
            return base

    # Try the remote's default branch
    remote_head = run_git_command(['git', 'symbolic-ref', '--short', 'refs/remotes/origin/HEAD'])
    if remote_head and '/' in remote_head:
        return remote_head.split('/', 1)[1]

    # Try to get default branch from git config
    default = run_git_command(['git', 'config', '--get', 'init.defaultBranch'])
    if default:
        return default

    # Check if main exists
    main_exists = run_git_command(['git', 'rev-parse', '--verify', 'main'])
    if main_exists:
        return 'main'

    # Fall back to master
    return 'master'


def extract_issue_key(branch_name: str) -> Optional[str]:
    """Extract a Thryx issue key from the branch name, e.g. PROJ-123."""
    match = re.search(r'([A-Z]+-\d+)', branch_name)
    return match.group(1) if match else None


def parse_conventional_commit(message: str) -> Dict[str, Optional[str]]:
    """Parse conventional commit message into components."""
    # Pattern: type(scope)!: subject
    pattern = r'^(\w+)(?:\(([^)]+)\))?(!)?:\s*(.+)$'
    match = re.match(pattern, message.split('\n')[0])

    if match:
        return {
            'type': match.group(1),
            'scope': match.group(2),
            'breaking': match.group(3) == '!',
            'subject': match.group(4),
            'raw': message
        }

    return {
        'type': None,
        'scope': None,
        'breaking': False,
        'subject': message.split('\n')[0],
        'raw': message
    }


def get_commits_between_branches(base_branch: str) -> List[Dict]:
    """Get all commits between current branch and base branch."""
    current_branch = get_current_branch()

    # Get commit hashes and messages
    log_output = run_git_command([
        'git', 'log',
        f'{base_branch}..{current_branch}',
        '--pretty=format:%H|||%s|||%b|||%an|||%ae|||%ad',
        '--date=iso'
    ])

    if not log_output:
        return []

    commits = []
    for line in log_output.split('\n'):
        if not line:
            continue

        parts = line.split('|||')
        if len(parts) >= 6:
            commit_hash, subject, body, author_name, author_email, date = parts[:6]
            full_message = f"{subject}\n\n{body}".strip()
            parsed = parse_conventional_commit(full_message)

            commits.append({
                'hash': commit_hash,
                'short_hash': commit_hash[:7],
                'subject': subject,
                'body': body.strip() if body else '',
                'author': author_name,
                'email': author_email,
                'date': date,
                'type': parsed['type'],
                'scope': parsed['scope'],
                'breaking': parsed['breaking'],
                'parsed_subject': parsed['subject']
            })

    return commits


def get_file_changes(base_branch: str) -> Dict[str, List[str]]:
    """Get all file changes between current branch and base branch."""
    current_branch = get_current_branch()

    # Get list of changed files with status
    diff_output = run_git_command([
        'git', 'diff',
        f'{base_branch}...{current_branch}',
        '--name-status'
    ])

    changes = {
        'added': [],
        'modified': [],
        'deleted': [],
        'renamed': []
    }

    for line in diff_output.split('\n'):
        if not line:
            continue

        parts = line.split('\t')
        if len(parts) < 2:
            continue

        status = parts[0][0]  # First character is the status
        filename = parts[1]

        if status == 'A':
            changes['added'].append(filename)
        elif status == 'M':
            changes['modified'].append(filename)
        elif status == 'D':
            changes['deleted'].append(filename)
        elif status == 'R':
            changes['renamed'].append(f"{parts[1]} → {parts[2]}" if len(parts) > 2 else filename)

    return changes


def categorize_files(files: List[str]) -> Dict[str, List[str]]:
    """Categorize files by type/area."""
    categories = {
        'code': [],
        'tests': [],
        'docs': [],
        'config': [],
        'styles': [],
        'build': [],
        'ci': [],
        'other': []
    }

    for file in files:
        file_lower = file.lower()

        if any(test in file_lower for test in ['test', 'spec', '__tests__', '.test.', '.spec.']):
            categories['tests'].append(file)
        elif any(doc in file_lower for doc in ['readme', '.md', 'doc/', 'docs/']):
            categories['docs'].append(file)
        elif any(ci in file_lower for ci in ['.github/workflows', '.gitlab-ci', 'jenkinsfile', '.circleci']):
            categories['ci'].append(file)
        elif any(build in file_lower for build in ['dockerfile', 'makefile', 'package.json', 'go.mod', 'cargo.toml', 'pom.xml', 'build.gradle']):
            categories['build'].append(file)
        elif any(cfg in file for cfg in ['.json', '.yaml', '.yml', '.toml', '.ini', 'config', '.env']):
            categories['config'].append(file)
        elif any(style in file for style in ['.css', '.scss', '.sass', '.less']):
            categories['styles'].append(file)
        elif any(ext in file for ext in ['.js', '.ts', '.tsx', '.jsx', '.py', '.java', '.go', '.rb', '.php', '.c', '.cpp', '.rs', '.swift', '.kt']):
            categories['code'].append(file)
        else:
            categories['other'].append(file)

    return {k: v for k, v in categories.items() if v}


def get_change_statistics(base_branch: str) -> Dict[str, int]:
    """Get detailed statistics about changes."""
    current_branch = get_current_branch()

    stat_output = run_git_command([
        'git', 'diff',
        f'{base_branch}...{current_branch}',
        '--stat'
    ])

    insertions = 0
    deletions = 0
    files_changed = 0

    # Parse the summary line (last line)
    lines = stat_output.split('\n')
    if lines:
        summary = lines[-1]
        # Pattern: "X files changed, Y insertions(+), Z deletions(-)"
        files_match = re.search(r'(\d+) files? changed', summary)
        insertions_match = re.search(r'(\d+) insertions?', summary)
        deletions_match = re.search(r'(\d+) deletions?', summary)

        if files_match:
            files_changed = int(files_match.group(1))
        if insertions_match:
            insertions = int(insertions_match.group(1))
        if deletions_match:
            deletions = int(deletions_match.group(1))

    return {
        'files_changed': files_changed,
        'insertions': insertions,
        'deletions': deletions,
        'total_changes': insertions + deletions
    }


def analyze_commit_types(commits: List[Dict]) -> Dict:
    """Analyze commit types to determine the primary type for PR."""
    types = [c['type'] for c in commits if c['type']]
    scopes = [c['scope'] for c in commits if c['scope']]

    type_counts = Counter(types)
    scope_counts = Counter(scopes)

    # Determine most common type
    most_common_type = type_counts.most_common(1)[0][0] if type_counts else None

    # Check for breaking changes
    has_breaking = any(c['breaking'] for c in commits)

    # Get unique scopes
    unique_scopes = list(set(scopes))

    return {
        'most_common_type': most_common_type,
        'type_counts': dict(type_counts),
        'scope_counts': dict(scope_counts),
        'unique_scopes': unique_scopes,
        'has_breaking_changes': has_breaking,
        'total_commits': len(commits),
        'conventional_commits': len(types),
        'non_conventional_commits': len(commits) - len(types)
    }


def check_branch_status() -> Dict:
    """Check if branch is up to date with remote."""
    current_branch = get_current_branch()

    # Check if branch has remote
    remote_branch = run_git_command(['git', 'rev-parse', '--abbrev-ref', f'{current_branch}@{{upstream}}'])

    if not remote_branch:
        return {
            'has_remote': False,
            'needs_push': True,
            'up_to_date': False
        }

    # Check if local is ahead/behind remote
    local_hash = run_git_command(['git', 'rev-parse', current_branch])
    remote_hash = run_git_command(['git', 'rev-parse', remote_branch])

    return {
        'has_remote': True,
        'needs_push': local_hash != remote_hash,
        'up_to_date': local_hash == remote_hash,
        'remote_branch': remote_branch
    }


def analyze_pr_changes(base_branch: Optional[str] = None) -> Dict:
    """Main function to analyze all PR-related changes."""
    if base_branch is None:
        base_branch = get_base_branch()

    current_branch = get_current_branch()
    issue_key = extract_issue_key(current_branch)

    commits = get_commits_between_branches(base_branch)
    file_changes = get_file_changes(base_branch)

    # Get all changed files for categorization
    all_changed_files = (
        file_changes['added'] +
        file_changes['modified'] +
        file_changes['deleted']
    )

    categorized = categorize_files(all_changed_files)
    stats = get_change_statistics(base_branch)
    commit_analysis = analyze_commit_types(commits)
    branch_status = check_branch_status()

    return {
        'branch': {
            'current': current_branch,
            'base': base_branch,
            'issue_key': issue_key
        },
        'commits': commits,
        'commit_analysis': commit_analysis,
        'files': {
            'changes': file_changes,
            'categorized': categorized,
            'all_changed': all_changed_files
        },
        'statistics': stats,
        'branch_status': branch_status
    }


def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(description='Analyze PR changes')
    parser.add_argument('--base', help='Base branch to compare against')
    parser.add_argument('--pretty', action='store_true', help='Pretty print JSON output')

    args = parser.parse_args()

    try:
        analysis = analyze_pr_changes(args.base)
        indent = 2 if args.pretty else None
        print(json.dumps(analysis, indent=indent))
        return 0
    except Exception as e:
        print(json.dumps({'error': str(e)}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
