#!/usr/bin/env python3
"""
CSV Reader Script
Reads a CSV file and displays its contents with basic statistics.
"""

import csv
import sys
from pathlib import Path


def read_csv(file_path):
    """
    Read a CSV file and display its contents.
    
    Args:
        file_path: Path to the CSV file
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            # Use csv.DictReader to read with headers
            reader = csv.DictReader(file)
            
            # Store rows for processing
            rows = list(reader)
            
            if not rows:
                print("The CSV file is empty.")
                return
            
            # Display file info
            print(f"File: {file_path}")
            print(f"Rows: {len(rows)}")
            print(f"Columns: {len(reader.fieldnames)}")
            print(f"\nColumn names: {', '.join(reader.fieldnames)}")
            print("\n" + "="*80)
            
            # Display first few rows
            print("\nFirst 5 rows:")
            for i, row in enumerate(rows[:5], 1):
                print(f"\nRow {i}:")
                for key, value in row.items():
                    print(f"  {key}: {value}")
            
            # Show total count if there are more rows
            if len(rows) > 5:
                print(f"\n... and {len(rows) - 5} more rows")
                
    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found.")
        sys.exit(1)
    except csv.Error as e:
        print(f"Error reading CSV file: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python read_csv.py <csv_file_path>")
        print("Example: python read_csv.py data.csv")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    read_csv(csv_file)
