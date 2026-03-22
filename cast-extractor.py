#!/usr/bin/env python
import re
import ast
import json
import argparse

def extract_input_lines(text):
    """
    Extracts only lines with user input (contain "i",)
    Format: [timestamp, "i", "data"]
    """
    lines = text.split('\n')
    input_lines = []

    for line in lines:
        line = line.strip()
        # Check that the line contains "i" and resembles the asciinema format
        if '"i",' in line and line.startswith('['):
            input_lines.append(line)

    return '\n'.join(input_lines)

def parse_asciinema_v2(text):
    """
    Parses asciinema v2 log (format [timestamp, "i", "data"])
    Emulates terminal cursor behavior
    """
    # First filter only input lines
    filtered_text = extract_input_lines(text)

    # Extract input events [timestamp, "i", "char"]
    pattern = r'\[([\d.]+),\s*"i",\s*("(?:[^"\\]|\\.)*")\s*\]'
    matches = re.findall(pattern, filtered_text)

    # Current line as a list of characters
    current_line = []
    cursor_pos = 0

    # Result – list of lines
    lines = []

    for timestamp, char_str in matches:
        try:
            # Decode escape sequences
            char = ast.literal_eval(char_str)
        except:
            char = char_str.strip('"')

        # Check for ANSI escape sequences
        if char.startswith('\x1b') or char.startswith('\u001b'):
            # Left arrow: ESC[D
            if char.endswith('[D') or char == '\u001b[D':
                cursor_pos = max(0, cursor_pos - 1)
            # Right arrow: ESC[C
            elif char.endswith('[C') or char == '\u001b[C':
                cursor_pos = min(len(current_line), cursor_pos + 1)
            # Ignore other escape sequences
            continue

        # Backspace (^? or \x7f)
        if char == '^?' or char == '\x7f':
            if cursor_pos > 0:
                del current_line[cursor_pos - 1]
                cursor_pos -= 1
            continue

        # Carriage return \r – end of line
        if char == '\r':
            lines.append(''.join(current_line))
            current_line = []
            cursor_pos = 0
            continue

        # Newline \n
        if char == '\n':
            lines.append(''.join(current_line))
            current_line = []
            cursor_pos = 0
            continue

        # Regular character – insert at current cursor position
        if cursor_pos >= len(current_line):
            current_line.append(char)
        else:
            # Overwrite mode
            current_line[cursor_pos] = char
        cursor_pos += 1

    # Append the final line
    if current_line or not lines:
        lines.append(''.join(current_line))

    return lines

def process_file(filename, output_path=None):
    """Processes an asciinema file and outputs the result"""
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()

    # Show filtering statistics
    original_lines = content.split('\n')
    filtered = extract_input_lines(content)
    filtered_count = len(filtered.split('\n')) if filtered else 0

    print(f"Original lines: {len(original_lines)}")
    print(f"Input lines ('i',): {filtered_count}")
    print("-" * 50)

    # Parse the log and obtain raw reconstructed lines
    lines = parse_asciinema_v2(content)

    # Filter out empty or non‑printable‑only lines
    filtered_lines = [ln for ln in lines if ln.strip() and any(ch.isprintable() for ch in ln)]

    print(f"\nRecognized lines (before filtering): {len(lines)}")
    print(f"Recognized lines (after filtering): {len(filtered_lines)}")
    print("=" * 50)

    # Report summary (no per-line output)
    print(f"Recognized lines (after filtering): {len(filtered_lines)}")
    print("Result will be written to the specified file.")

    # Prepare JSON report
    report = {
        "input_file": filename,
        "statistics": {
            "original_lines": len(original_lines),
            "input_events": filtered_count,
            "reconstructed_lines_total": len(lines),
            "reconstructed_lines_filtered": len(filtered_lines)
        },
        "lines": filtered_lines
    }

    # Write JSON report to the output file (mandatory)
    with open(output_path, 'w', encoding='utf-8') as out_f:
        json.dump(report, out_f, ensure_ascii=False, indent=2)
    print(f"✓ JSON report saved to {output_path}")
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process an asciinema cast file.")
    parser.add_argument("input", help="Path to the cast file")
    parser.add_argument("-o", "--output", help="File to write the result to", required=True)
    args = parser.parse_args()
    process_file(args.input, args.output)

