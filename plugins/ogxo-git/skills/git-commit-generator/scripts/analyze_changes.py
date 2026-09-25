#!/usr/bin/env python3
"""
Git Change Analyzer

Analyzes git changes and provides structured data for commit message generation.
Returns JSON with file changes, statistics, and metadata.
"""

import subprocess
import json
import sys
import re
from typing import Dict, List, Optional

class GitError(Exception):
    """A git command the analysis depends on failed."""

def run_git_command(command: List[str], required: bool = True) -> str:
    """Run a git command and return its output.

    A required command raises GitError when git fails, so an error is
    reported instead of being read as "nothing staged". Probes pass
    required=False and get "" back.
    """
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        if required:
            detail = result.stderr.strip() or f"exit {result.returncode}"
            raise GitError(f"{' '.join(command)}: {detail}")
        return ""
    return result.stdout.strip()

def get_current_branch() -> str:
    """Get the current git branch name, including a branch with no commits yet."""
    return (run_git_command(['git', 'symbolic-ref', '--short', 'HEAD'], required=False)
            or run_git_command(['git', 'rev-parse', '--short', 'HEAD'], required=False))

def extract_issue_key(branch_name: str) -> Optional[str]:
    """Extract a Thryx issue key from the branch name, e.g. PROJ-123."""
    match = re.search(r'([A-Z]+-\d+)', branch_name)
    return match.group(1) if match else None

def get_staged_files() -> List[str]:
    """Get list of staged files."""
    output = run_git_command(['git', 'diff', '--staged', '--name-only'])
    return [f for f in output.split('\n') if f]

def get_unstaged_files() -> List[str]:
    """Get list of unstaged files."""
    output = run_git_command(['git', 'diff', '--name-only'])
    return [f for f in output.split('\n') if f]

def get_untracked_files() -> List[str]:
    """Get list of untracked files."""
    output = run_git_command(['git', 'ls-files', '--others', '--exclude-standard'])
    return [f for f in output.split('\n') if f]

def get_diff_stats() -> Dict[str, int]:
    """Get statistics about changes (insertions, deletions)."""
    output = run_git_command(['git', 'diff', '--staged', '--numstat'])
    insertions = 0
    deletions = 0

    for line in output.split('\n'):
        if line:
            parts = line.split('\t')
            if len(parts) >= 2:
                try:
                    insertions += int(parts[0]) if parts[0] != '-' else 0
                    deletions += int(parts[1]) if parts[1] != '-' else 0
                except ValueError:
                    pass

    return {
        'insertions': insertions,
        'deletions': deletions,
        'files_changed': len(get_staged_files())
    }

def get_staged_diff() -> str:
    """Get the full diff of staged changes."""
    return run_git_command(['git', 'diff', '--staged'])

def get_recent_commits(count: int = 5) -> List[str]:
    """Get recent commit messages for style reference."""
    # A repository with no commits yet has no log, which is not an error here.
    output = run_git_command(['git', 'log', f'-{count}', '--pretty=format:%s'], required=False)
    return [msg for msg in output.split('\n') if msg]

def categorize_files(files: List[str]) -> Dict[str, List[str]]:
    """Categorize files by type/area."""
    categories = {
        'code': [],
        'tests': [],
        'docs': [],
        'config': [],
        'styles': [],
        'other': []
    }

    for file in files:
        if any(test in file.lower() for test in ['test', 'spec', '__tests__']):
            categories['tests'].append(file)
        elif any(doc in file.lower() for doc in ['readme', '.md', 'doc']):
            categories['docs'].append(file)
        elif any(cfg in file for cfg in ['.json', '.yaml', '.yml', '.toml', '.ini', 'config']):
            categories['config'].append(file)
        elif any(style in file for style in ['.css', '.scss', '.sass', '.less']):
            categories['styles'].append(file)
        elif any(ext in file for ext in ['.js', '.ts', '.py', '.java', '.go', '.rb', '.php', '.c', '.cpp', '.rs']):
            categories['code'].append(file)
        else:
            categories['other'].append(file)

    return {k: v for k, v in categories.items() if v}

def analyze_changes() -> Dict:
    """Analyze all git changes and return structured data."""
    if not run_git_command(['git', 'rev-parse', '--is-inside-work-tree'], required=False):
        raise GitError('not inside a git repository')
    branch = get_current_branch()
    staged_files = get_staged_files()

    analysis = {
        'branch': {
            'name': branch,
            'issue_key': extract_issue_key(branch)
        },
        'files': {
            'staged': staged_files,
            'unstaged': get_unstaged_files(),
            'untracked': get_untracked_files(),
            'categorized': categorize_files(staged_files)
        },
        'stats': get_diff_stats(),
        'recent_commits': get_recent_commits(),
        'has_staged_changes': len(staged_files) > 0
    }

    return analysis

def main():
    """Main entry point."""
    try:
        analysis = analyze_changes()
        print(json.dumps(analysis, indent=2))
        return 0
    except Exception as e:
        print(json.dumps({'error': str(e)}), file=sys.stderr)
        return 1

if __name__ == '__main__':
    sys.exit(main())
