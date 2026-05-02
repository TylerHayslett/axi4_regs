#!/usr/bin/env python3
"""
CSV Reader Script with Pandas
Reads a CSV file and provides analysis using pandas.
"""

import sys
from pathlib import Path

try:
    import pandas as pd
except ImportError:
    print("Error: pandas is not installed. Install it with: pip install pandas")
    sys.exit(1)


def read_csv_with_pandas(file_path):
    """
    Read a CSV file using pandas and display analysis.
    
    Args:
        file_path: Path to the CSV file
        
    Returns:
        pandas.DataFrame: The loaded data
    """
    try:
        # Read CSV into pandas DataFrame
        df = pd.read_csv(file_path)
        
        if df.empty:
            print("The CSV file is empty.")
            return None
        
        # Display basic information
        print(f"File: {file_path}")
        print(f"\nDataFrame Shape: {df.shape[0]} rows × {df.shape[1]} columns")
        print("="*80)
        
        # Show column information
        print("\nColumn Information:")
        print(df.dtypes)
        
        # Display first few rows
        print("\n" + "="*80)
        print("\nFirst 5 rows:")
        print(df.head())
        
        # Show basic statistics for numeric columns
        if df.select_dtypes(include='number').shape[1] > 0:
            print("\n" + "="*80)
            print("\nNumeric Column Statistics:")
            print(df.describe())
        
        # Show missing values
        missing = df.isnull().sum()
        if missing.any():
            print("\n" + "="*80)
            print("\nMissing Values:")
            print(missing[missing > 0])
        else:
            print("\n" + "="*80)
            print("\nNo missing values detected.")
        
        # Memory usage
        print("\n" + "="*80)
        print(f"\nMemory Usage: {df.memory_usage(deep=True).sum() / 1024:.2f} KB")
        
        return df
        
    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found.")
        sys.exit(1)
    except pd.errors.EmptyDataError:
        print("Error: The CSV file is empty or invalid.")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading CSV file: {e}")
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python read_csv.py <csv_file_path>")
        print("Example: python read_csv.py data.csv")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    df = read_csv_with_pandas(csv_file)
    
    # Optionally, you can do additional pandas operations here
    # Examples:
    # df_filtered = df[df['column_name'] > 100]
    # df_sorted = df.sort_values('column_name')
    # df.to_csv('output.csv', index=False)
