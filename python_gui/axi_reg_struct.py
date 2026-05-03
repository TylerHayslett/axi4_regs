#!/usr/bin/env python3

import pandas as pd

def parse_regs(df):
    print("there are " + str(len(df)) + " rows in the dataframe")
    #for _, row in df.iterrows():
    #    print("Row " + str(row))
    return df

def read_csv_to_df(filename):
    """Read a CSV file into a pandas DataFrame."""
    try:
        df = pd.read_csv(filename)
        df = clean_df(df)
        df['Description'] = df['Description'].str.replace(r'\\n', '\n', regex=True)
        df = parse_regs(df)

        return df
    except Exception as e:
        print(f"Error reading CSV file: {e}")
        return None

def write_df_to_csv(df, file_path):
    """Write a pandas DataFrame to a CSV file."""
    try:
        df_temp = df.copy(deep=True)
        df_temp['Description'] = df_temp['Description'].str.replace('\n', r'\\n', regex=True)
        df_temp.to_csv(file_path, index=False, quoting=csv.QUOTE_NONNUMERIC)
    except Exception as e:
        print(f"Error writing CSV file: {e}")


def clean_df(df):
    """Clean the DataFrame by replacing empty strings with NA and dropping empty rows."""
    df_temp = df.copy(deep=True)
    df_temp = df_temp.replace(r'^\s*$', pd.NA, regex=True)
    df_temp = df_temp.dropna(how='all').reset_index(drop=True)
    return df_temp

