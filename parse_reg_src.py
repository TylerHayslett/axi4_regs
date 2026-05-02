#!/usr/bin/env python3
"""
CSV Reader with PandasTable (Tkinter GUI)
Reads a CSV file and displays it using the pandastable library.
"""

import sys
from pathlib import Path

try:
    import pandas as pd
except ImportError:
    print("Error: pandas is not installed. Install it with: pip install pandas")
    sys.exit(1)

try:
    from pandastable import Table, TableModel
    import tkinter as tk
    from tkinter import ttk
except ImportError:
    print("Error: pandastable is not installed.")
    print("Install it with: pip install pandastable")
    print("\nNote: This also requires tkinter, which comes with Python on most systems.")
    sys.exit(1)


class CSVViewer:
    """CSV Viewer application using pandastable."""
    
    def __init__(self, csv_file):
        self.csv_file = csv_file
        self.df = None
        self.root = tk.Tk()
        self.setup_window()
        self.load_data()
        
    def setup_window(self):
        """Setup the main window."""
        self.root.title(f"CSV Viewer - {Path(self.csv_file).name}")
        self.root.geometry("1200x700")
        
        # Create info frame at top
        info_frame = ttk.Frame(self.root, padding="10")
        info_frame.pack(side=tk.TOP, fill=tk.X)
        
        self.info_label = ttk.Label(info_frame, text="Loading...", font=('Arial', 10))
        self.info_label.pack(side=tk.LEFT)
        
        # Create main frame for table
        self.main_frame = tk.Frame(self.root)
        self.main_frame.pack(fill=tk.BOTH, expand=True)
        
    def load_data(self):
        """Load CSV data and create table."""
        try:
            # Read CSV file
            self.df = pd.read_csv(self.csv_file)
            
            if self.df.empty:
                self.info_label.config(text="Error: CSV file is empty")
                return
            
            # Update info label
            rows, cols = self.df.shape
            missing = self.df.isnull().sum().sum()
            info_text = (f"File: {self.csv_file} | "
                        f"Rows: {rows:,} | "
                        f"Columns: {cols} | "
                        f"Missing values: {missing}")
            self.info_label.config(text=info_text)
            
            # Create the table
            self.table = Table(self.main_frame, dataframe=self.df,
                             showtoolbar=True, showstatusbar=True)
            self.table.show()
            
            # Print summary to console
            print(f"\n{'='*80}")
            print(f"CSV Viewer - {Path(self.csv_file).name}")
            print(f"{'='*80}")
            print(f"Rows: {rows:,}")
            print(f"Columns: {cols}")
            print(f"Column names: {', '.join(self.df.columns.tolist())}")
            print(f"Missing values: {missing}")
            print(f"\nData types:")
            print(self.df.dtypes)
            print(f"\n{'='*80}")
            print("Table opened in GUI window. Close the window to exit.")
            
        except FileNotFoundError:
            self.info_label.config(text=f"Error: File '{self.csv_file}' not found")
            print(f"Error: File '{self.csv_file}' not found.")
            sys.exit(1)
        except pd.errors.EmptyDataError:
            self.info_label.config(text="Error: CSV file is empty or invalid")
            print("Error: The CSV file is empty or invalid.")
            sys.exit(1)
        except Exception as e:
            self.info_label.config(text=f"Error: {str(e)}")
            print(f"Error reading CSV file: {e}")
            sys.exit(1)
    
    def run(self):
        """Start the GUI event loop."""
        self.root.mainloop()


def main():
    """Main function."""
    if len(sys.argv) < 2:
        print("CSV Reader with PandasTable")
        print("="*50)
        print("\nUsage: python read_csv_pandastable.py <csv_file_path>")
        print("Example: python read_csv_pandastable.py data.csv")
        print("\nThis will open an interactive GUI window with:")
        print("  - Sortable columns")
        print("  - Built-in toolbar for data manipulation")
        print("  - Plotting capabilities")
        print("  - Export options")
        print("\nRequirements:")
        print("  pip install pandas pandastable")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    
    # Create and run the viewer
    viewer = CSVViewer(csv_file)
    viewer.run()


if __name__ == "__main__":
    main()
