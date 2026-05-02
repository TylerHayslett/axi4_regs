#!/usr/bin/env python3


def write_rows_to_file(df, filename="output.h"):
    """Write each row of a pandas DataFrame to a line in the given file."""
    with open(filename, "w") as f:
        f.write("// Auto-generated header file\n")
        f.write("#ifndef OUTPUT_H\n")
        f.write("#define OUTPUT_H\n")
        f.write("\n")
        for _, row in df.iterrows():
            f.write("// " + ", ".join(str(v) for v in row.values) + "\n")
        f.write("\n")
        f.write("#endif // OUTPUT_H\n")
