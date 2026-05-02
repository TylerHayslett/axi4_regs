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
    from tkinter import ttk, filedialog, messagebox
except ImportError:
    print("Error: pandastable is not installed.")
    print("Install it with: pip install pandastable")
    print("\nNote: This also requires tkinter, which comes with Python on most systems.")
    sys.exit(1)


class AutoSaveTable(Table):
    """Custom Table that auto-saves cell edits on focus loss."""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
    def handle_left_click(self, event):
        """Override to save cell entry before moving to next cell."""
        print("Autosaving...")
        # Save the current cell entry if it exists
        if hasattr(self, 'cellentry') and self.cellentry.winfo_exists():
            self.handle_entry_save()
        
        # Call the parent's left click handler
        super().handle_left_click(event)
    
    def handle_entry_save(self):
        """Save the current cell entry value."""
        try:
            if hasattr(self, 'cellentry'):
                row = self.currentrow
                col = self.currentcol
                text = self.cellentry.get()
                print(f"saving {text} at {row} {col}")
                # Update the model
                self.model.setValueAt(text, row, col)
                self.redraw()
                
        except Exception as e:
            print(f"Error saving cell: {e}")
    
    def drawCellEntry(self, row, col, text=None):
        """Override to bind focus out event."""
        super().drawCellEntry(row, col, text)
        
        # Bind focus out to save
        if hasattr(self, 'cellentry'):
            self.cellentry.bind('<FocusOut>', lambda e: self.handle_entry_save())
            # Also save on Escape key
            self.cellentry.bind('<Escape>', lambda e: self.handle_entry_save())


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
        
        # Button frame on the right
        button_frame = ttk.Frame(info_frame)
        button_frame.pack(side=tk.RIGHT)
        
        # Add row button
        add_row_btn = ttk.Button(button_frame, text="➕ Add Row", 
                                command=self.add_row)
        add_row_btn.pack(side=tk.LEFT, padx=2)
        
        # Delete row button
        delete_row_btn = ttk.Button(button_frame, text="🗑️ Delete Row(s)", 
                                   command=self.delete_rows)
        delete_row_btn.pack(side=tk.LEFT, padx=2)
        
        # Export button
        export_btn = ttk.Button(button_frame, text="📥 Export to CSV", 
                               command=self.export_to_csv)
        export_btn.pack(side=tk.LEFT, padx=2)
        
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
            
            # Create the table with auto-save functionality
            self.table = AutoSaveTable(self.main_frame, dataframe=self.df,
                                      showtoolbar=True, showstatusbar=True,
                                      editable=True)
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
    
    def export_to_csv(self):
        """Export the current DataFrame to a CSV file."""
        if self.df is None:
            messagebox.showerror("Error", "No data to export")
            return
        
        try:
            # Get the current dataframe from the table (in case user made changes)
            current_df = self.table.model.df
            
            # Open file dialog to choose save location
            default_filename = Path(self.csv_file).stem + "_exported.csv"
            file_path = filedialog.asksaveasfilename(
                defaultextension=".csv",
                filetypes=[("CSV files", "*.csv"), ("All files", "*.*")],
                initialfile=default_filename,
                title="Export to CSV"
            )
            
            if file_path:  # If user didn't cancel
                current_df.to_csv(file_path, index=False)
                messagebox.showinfo("Success", f"Data exported successfully to:\n{file_path}")
                print(f"\n✓ Data exported to: {file_path}")
                
        except Exception as e:
            messagebox.showerror("Export Error", f"Failed to export data:\n{str(e)}")
            print(f"Export error: {e}")
    
    def add_row(self):
        """Add a new empty row to the table."""
        if self.table is None:
            return
        
        try:
            # Get current dataframe
            df = self.table.model.df
            
            # Create a new row with NaN values (or empty strings for object columns)
            new_row = {}
            for col in df.columns:
                if df[col].dtype == 'object':
                    new_row[col] = ''
                else:
                    new_row[col] = pd.NA
            
            # Add the new row using pandas concat
            new_df = pd.concat([df, pd.DataFrame([new_row])], ignore_index=True)
            
            # Update the table model with the new dataframe
            self.table.model.df = new_df
            self.table.redraw()
            
            # Scroll to bottom to show the new row
            self.table.setSelectedRow(len(new_df) - 1)
            
            # Update info label
            rows = len(new_df)
            cols = len(new_df.columns)
            missing = new_df.isnull().sum().sum()
            info_text = (f"File: {self.csv_file} | "
                        f"Rows: {rows:,} | "
                        f"Columns: {cols} | "
                        f"Missing values: {missing}")
            self.info_label.config(text=info_text)
            
            print(f"✓ Added new row (total rows: {rows})")
            print(f"  Tip: Double-click cells to edit them")
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to add row:\n{str(e)}")
            print(f"Add row error: {e}")
    
    def delete_rows(self):
        """Delete selected row(s) from the table."""
        if self.table is None:
            return
        
        try:
            # Get selected rows
            if not hasattr(self.table, 'multiplerowlist') or len(self.table.multiplerowlist) == 0:
                messagebox.showwarning("No Selection", 
                                     "Please select one or more rows to delete.\n\n"
                                     "Tip: Click on row numbers to select rows.")
                return
            
            num_selected = len(self.table.multiplerowlist)
            
            # Ask for confirmation
            response = messagebox.askyesno("Confirm Delete", 
                                          f"Delete {num_selected} selected row(s)?")
            
            if response:
                self.table.deleteRow()
                self.table.redraw()
                
                # Update info label
                rows = len(self.table.model.df)
                cols = len(self.table.model.df.columns)
                missing = self.table.model.df.isnull().sum().sum()
                info_text = (f"File: {self.csv_file} | "
                            f"Rows: {rows:,} | "
                            f"Columns: {cols} | "
                            f"Missing values: {missing}")
                self.info_label.config(text=info_text)
                
                print(f"✓ Deleted {num_selected} row(s) (total rows: {rows})")
                
        except Exception as e:
            messagebox.showerror("Error", f"Failed to delete rows:\n{str(e)}")
            print(f"Delete row error: {e}")
    
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
        print("  - ➕ Add Row button - adds empty rows")
        print("  - 🗑️ Delete Row(s) button - removes selected rows")
        print("  - 📥 Export to CSV button - saves your changes")
        print("  - Double-click cells to edit values")
        print("  - Auto-save on clicking away (no need to press Enter!)")
        print("  - Plotting capabilities")
        print("\nTips:")
        print("  - Double-click any cell to edit its value")
        print("  - Click away or press Enter to save changes")
        print("  - Click row numbers to select rows for deletion")
        print("  - Use Ctrl+Click (Cmd+Click on Mac) to select multiple rows")
        print("\nRequirements:")
        print("  pip install pandas pandastable")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    
    # Create and run the viewer
    viewer = CSVViewer(csv_file)
    viewer.run()


if __name__ == "__main__":
    main()
