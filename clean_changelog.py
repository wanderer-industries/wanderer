#!/usr/bin/env python3
"""
Script to clean up CHANGELOG.md by removing empty version entries.
An empty version entry has only a version header followed by empty lines,
without any actual content (### Bug Fixes: or ### Features: sections).
"""

import re

def clean_changelog():
    with open('./CHANGELOG.md', 'r') as f:
        content = f.read()

    # Split content into sections based on version headers
    version_pattern = r'^## \[v\d+\.\d+\.\d+\].*?\([^)]+\)$'

    # Find all version headers with their positions
    matches = list(re.finditer(version_pattern, content, re.MULTILINE))

    # Build new content by keeping only non-empty versions
    new_content = ""

    # Keep the header (everything before first version)
    if matches:
        new_content += content[:matches[0].start()]
    else:
        # No versions found, keep original
        return content

    for i, match in enumerate(matches):
        version_start = match.start()

        # Find the end of this version section (start of next version or end of file)
        if i + 1 < len(matches):
            version_end = matches[i + 1].start()
        else:
            version_end = len(content)

        version_section = content[version_start:version_end]

        # Check if this version has actual content
        # Look for ### Bug Fixes: or ### Features: followed by actual content
        has_content = False

        # Split the section into lines
        lines = version_section.split('\n')

        # Look for content sections
        in_content_section = False
        for line in lines:
            line_stripped = line.strip()

            # Check if we're entering a content section
            if line_stripped.startswith('### Bug Fixes:') or line_stripped.startswith('### Features:'):
                in_content_section = True
                continue

            # If we're in a content section and find non-empty content
            if in_content_section:
                if line_stripped and not line_stripped.startswith('###') and not line_stripped.startswith('##'):
                    # This is actual content (not just another header)
                    if line_stripped.startswith('*') or len(line_stripped) > 0:
                        has_content = True
                        break
                elif line_stripped.startswith('##'):
                    # We've reached the next version, stop looking
                    break

        # Only keep versions with actual content
        if has_content:
            new_content += version_section

    return new_content

if __name__ == "__main__":
    cleaned_content = clean_changelog()

    # Write the cleaned content back to the file
    with open('./CHANGELOG.md', 'w') as f:
        f.write(cleaned_content)

    print("CHANGELOG.md has been cleaned up successfully!")
