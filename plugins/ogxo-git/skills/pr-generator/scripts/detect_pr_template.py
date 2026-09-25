#!/usr/bin/env python3
"""
PR Template Detector

Detects and retrieves pull request templates from GitHub repository.
Searches common template locations and returns the template content.
"""

import os
import json
import sys
from pathlib import Path
from typing import Optional, Dict, List


def find_pr_template() -> Optional[Dict]:
    """
    Search for PR template in common GitHub locations.

    Returns dictionary with template info or None if not found.
    """
    # Common PR template locations in order of preference
    template_paths = [
        '.github/PULL_REQUEST_TEMPLATE.md',
        '.github/pull_request_template.md',
        '.github/PULL_REQUEST_TEMPLATE',
        'PULL_REQUEST_TEMPLATE.md',
        'pull_request_template.md',
        'docs/PULL_REQUEST_TEMPLATE.md',
        'docs/pull_request_template.md',
    ]

    # Check for template directory
    template_dir_paths = [
        '.github/PULL_REQUEST_TEMPLATE/',
        'PULL_REQUEST_TEMPLATE/',
    ]

    # Check individual template files first
    for template_path in template_paths:
        full_path = Path(template_path)
        if full_path.exists() and full_path.is_file():
            try:
                content = full_path.read_text(encoding='utf-8')
                return {
                    'found': True,
                    'path': str(full_path),
                    'type': 'file',
                    'content': content
                }
            except Exception as e:
                # File exists but couldn't read it
                return {
                    'found': True,
                    'path': str(full_path),
                    'type': 'file',
                    'error': str(e)
                }

    # Check template directories
    for template_dir in template_dir_paths:
        dir_path = Path(template_dir)
        if dir_path.exists() and dir_path.is_dir():
            # Get all .md files in the directory
            templates = list(dir_path.glob('*.md'))
            if templates:
                # Return info about available templates
                template_list = []
                for tmpl in templates:
                    try:
                        content = tmpl.read_text(encoding='utf-8')
                        template_list.append({
                            'name': tmpl.name,
                            'path': str(tmpl),
                            'content': content
                        })
                    except Exception as e:
                        template_list.append({
                            'name': tmpl.name,
                            'path': str(tmpl),
                            'error': str(e)
                        })

                return {
                    'found': True,
                    'path': str(dir_path),
                    'type': 'directory',
                    'templates': template_list
                }

    return None


def parse_template_sections(content: str) -> Dict[str, List[str]]:
    """
    Parse template content and identify sections.

    Returns dictionary with section names and their indicators.
    """
    sections = {
        'summary': [],
        'description': [],
        'changes': [],
        'testing': [],
        'issues': [],
        'breaking': [],
        'checklist': [],
        'screenshots': [],
        'other': []
    }

    lines = content.split('\n')

    for line in lines:
        line_lower = line.lower()

        # Check for section headers
        if any(word in line_lower for word in ['## summary', '## overview', '## description']):
            sections['summary'].append(line)
        elif any(word in line_lower for word in ['## changes', '## what', "## what's changed"]):
            sections['changes'].append(line)
        elif any(word in line_lower for word in ['## test', '## testing', '## validation']):
            sections['testing'].append(line)
        elif any(word in line_lower for word in ['## issue', '## related', '## closes', '## fixes']):
            sections['issues'].append(line)
        elif any(word in line_lower for word in ['## breaking', '## breaking change']):
            sections['breaking'].append(line)
        elif any(word in line_lower for word in ['## checklist', '## pre-merge', '## reviewer']):
            sections['checklist'].append(line)
        elif any(word in line_lower for word in ['## screenshot', '## visual', '## demo']):
            sections['screenshots'].append(line)
        elif line.startswith('##'):
            sections['other'].append(line)

    # Remove empty sections
    return {k: v for k, v in sections.items() if v}


def analyze_template(template_info: Optional[Dict]) -> Dict:
    """Analyze template and return structured information."""
    if not template_info or not template_info.get('found'):
        return {
            'has_template': False,
            'use_default': True
        }

    if template_info.get('type') == 'file':
        content = template_info.get('content', '')
        sections = parse_template_sections(content)

        return {
            'has_template': True,
            'use_default': False,
            'template_path': template_info['path'],
            'template_type': 'file',
            'sections': sections,
            'content': content
        }

    elif template_info.get('type') == 'directory':
        templates = template_info.get('templates', [])

        return {
            'has_template': True,
            'use_default': False,
            'template_path': template_info['path'],
            'template_type': 'directory',
            'available_templates': [
                {
                    'name': t['name'],
                    'path': t['path'],
                    'sections': parse_template_sections(t.get('content', ''))
                }
                for t in templates if 'content' in t
            ]
        }

    return {
        'has_template': False,
        'use_default': True
    }


def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(description='Detect PR template')
    parser.add_argument('--pretty', action='store_true', help='Pretty print JSON output')
    parser.add_argument('--content-only', action='store_true', help='Output only template content')

    args = parser.parse_args()

    try:
        template_info = find_pr_template()
        analysis = analyze_template(template_info)

        if args.content_only:
            if template_info and template_info.get('content'):
                print(template_info['content'])
            else:
                print("No template found", file=sys.stderr)
                return 1
        else:
            indent = 2 if args.pretty else None
            print(json.dumps(analysis, indent=indent))

        return 0
    except Exception as e:
        print(json.dumps({'error': str(e)}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
