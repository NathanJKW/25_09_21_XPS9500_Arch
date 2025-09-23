#!/usr/bin/env python3
import os
import sys
import argparse

# -------------------------------
# Configuration
# -------------------------------

# Only files with these extensions will be included
WHITELIST_EXTENSIONS = [".py", ".sh", ".qml", ".desktop"]

# These folders will be excluded completely
BLACKLIST_FOLDERS = ["__pycache__", ".git", ".venv", ".prompts"]

# These specific files will be excluded
BLACKLIST_FILES = ["context.py", "README.md", "alpine.min.js", "context.md"]

# Folder where template prompts are stored
TEMPLATE_FOLDER = ".prompts"

# Output file name
OUTPUT_FILE = "context.md"


# -------------------------------
# Helper Functions
# -------------------------------

def is_included_file(filepath):
    """Check if file should be included based on whitelist and blacklists."""
    filename = os.path.basename(filepath)
    folder_parts = filepath.split(os.sep)

    # Skip blacklisted files
    if filename in BLACKLIST_FILES:
        return False

    # Skip blacklisted folders
    for part in folder_parts:
        if part in BLACKLIST_FOLDERS:
            return False

    # Only include whitelisted extensions
    _, ext = os.path.splitext(filename)
    return ext in WHITELIST_EXTENSIONS


def collect_files(root="."):
    """Walk through directory and collect included files."""
    included_files = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Exclude blacklisted folders during walk
        dirnames[:] = [d for d in dirnames if d not in BLACKLIST_FOLDERS]

        for filename in filenames:
            filepath = os.path.join(dirpath, filename)
            if is_included_file(filepath):
                included_files.append(filepath)
    return sorted(included_files)


def build_file_tree(files, root="."):
    """Return a simple tree-like text representation of included files."""
    tree_lines = []
    for filepath in files:
        relpath = os.path.relpath(filepath, root)
        tree_lines.append(relpath)
    return "\n".join(tree_lines)


def load_template(template_name):
    """Load a template file if specified."""
    if not template_name:
        return ""
    template_path = os.path.join(TEMPLATE_FOLDER, template_name)
    if not os.path.exists(template_path):
        print(f"Template not found: {template_path}")
        sys.exit(1)
    with open(template_path, "r", encoding="utf-8") as f:
        return f.read().strip() + "\n\n"


def build_context_file(template_name=None, dry_run=False):
    files = collect_files()
    if dry_run:
        print("Dry run: included files\n")
        for f in files:
            print(f)
        return

    # Build sections
    template_content = load_template(template_name)
    file_tree = build_file_tree(files)
    file_contents = []

    for f in files:
        relpath = os.path.relpath(f)
        with open(f, "r", encoding="utf-8", errors="ignore") as fh:
            content = fh.read()
        file_contents.append(f"\n--- {relpath} ---\n{content}\n")

    # Write context file
    with open(OUTPUT_FILE, "w", encoding="utf-8") as out:
        out.write(template_content)
        out.write("<File Tree>\n")
        out.write(file_tree)
        out.write("\n\n<Contents of included files>\n")
        out.writelines(file_contents)

    print(f"Context file created: {OUTPUT_FILE}")


# -------------------------------
# Main
# -------------------------------

def main():
    parser = argparse.ArgumentParser(description="Build context file for ChatGPT")
    parser.add_argument("--template", help="Template filename from templates folder", default=None)
    parser.add_argument("--dry-run", action="store_true", help="List included files without writing output")
    args = parser.parse_args()

    build_context_file(template_name=args.template, dry_run=args.dry_run)


if __name__ == "__main__":
    main()