#!/usr/bin/env python3

import sys
import signal
import csv
import pandas as pd

import write_dot_h
import write_sys_verilog
import write_uvm_ral
import write_vhdl
import axi_reg_struct as axi_rs

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QTableView,
    QFileDialog, QWidget, QVBoxLayout,
    QPushButton, QHBoxLayout, QMessageBox,
    QStyledItemDelegate, QTextEdit, QLineEdit
)
from PyQt6.QtCore import Qt, QAbstractTableModel, QModelIndex, QTimer

class MultiLineDelegate(QStyledItemDelegate):
    def __init__(self, table, multiline_columns=None, allowed_values=None):
        super().__init__(table)
        self.table = table
        self.multiline_columns = multiline_columns or []
        # Mapping {column_name: [allowed values...]} for restricted columns.
        self.allowed_values = allowed_values or {}

    def _column_name(self, index):
        return index.model()._df.columns[index.column()]

    def createEditor(self, parent, option, index):
        col_name = self._column_name(index)

        # Only use QTextEdit for selected columns
        if col_name in self.multiline_columns:
            editor = QTextEdit(parent)
            editor.setAcceptRichText(False)

            # Ctrl+Enter commits edit
            def keyPressEvent(event):
                if event.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter) and \
                   event.modifiers() & Qt.KeyboardModifier.ControlModifier:
                    self.commitData.emit(editor)
                    self.closeEditor.emit(editor)
                else:
                    QTextEdit.keyPressEvent(editor, event)

                # Live resize while typing
                self.auto_resize(editor)

            editor.keyPressEvent = keyPressEvent

            # Also resize on text change
            editor.textChanged.connect(lambda: self.auto_resize(editor))

            return editor

        # Default editor for other columns
        return super().createEditor(parent, option, index)

    def setEditorData(self, editor, index):
        if isinstance(editor, QTextEdit):
            text = index.model().data(index, Qt.ItemDataRole.EditRole)
            editor.setPlainText(text)
            self.auto_resize(editor)
        else:
            super().setEditorData(editor, index)

    def setModelData(self, editor, model, index):
        if isinstance(editor, QTextEdit):
            text = editor.toPlainText()
            model.setData(index, text, Qt.ItemDataRole.EditRole)
            return

        col_name = self._column_name(index)
        if col_name in self.allowed_values and isinstance(editor, QLineEdit):
            raw = editor.text().strip()
            allowed = self.allowed_values[col_name]
            match = next((a for a in allowed if a.lower() == raw.lower()), None)
            if match is None:
                QMessageBox.warning(
                    self.table, f"Invalid {col_name}",
                    f"'{raw}' is not allowed.\nAllowed values: {', '.join(allowed)}"
                )
                # Re-open the editor on this cell so focus stays here.
                QTimer.singleShot(0, lambda: self.table.edit(index))
                return
            model.setData(index, match, Qt.ItemDataRole.EditRole)
            return

        super().setModelData(editor, model, index)

    def auto_resize(self, editor):
        """Resize row height based on editor content"""
        doc_height = editor.document().size().height()
        row = self.table.currentIndex().row()

        # Add some padding
        new_height = int(doc_height) + 10

        if new_height > self.table.rowHeight(row):
            self.table.setRowHeight(row, new_height)


class PandasModel(QAbstractTableModel):
    def __init__(self, df):
        super().__init__()
        self._df = df

    def rowCount(self, parent=None):
        return len(self._df)

    def columnCount(self, parent=None):
        return len(self._df.columns)

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if role in (Qt.ItemDataRole.DisplayRole, Qt.ItemDataRole.EditRole):
            value = self._df.iat[index.row(), index.column()]
            return str(value)
        return None

    def headerData(self, section, orientation, role):
        if role == Qt.ItemDataRole.DisplayRole:
            if orientation == Qt.Orientation.Horizontal:
                return str(self._df.columns[section])
            else:
                return str(section)
        return None

    # ✅ Make cells editable
    def flags(self, index):
        return (
            Qt.ItemFlag.ItemIsSelectable
            | Qt.ItemFlag.ItemIsEnabled
            | Qt.ItemFlag.ItemIsEditable
        )

    # ✅ Handle edits
    def setData(self, index, value, role=Qt.ItemDataRole.EditRole):
        if role == Qt.ItemDataRole.EditRole:
            row = index.row()
            col = index.column()

            current = self._df.iat[row, col]

            # Try to preserve type
            try:
                if isinstance(current, int):
                    value = int(value)
                elif isinstance(current, float):
                    value = float(value)
            except ValueError:
                return False  # reject invalid input

            self._df.iat[row, col] = value

            self.dataChanged.emit(index, index, [Qt.ItemDataRole.DisplayRole])
            return True

        return False

    def insertRow(self, position, parent=QModelIndex()):
        self.beginInsertRows(QModelIndex(), position, position)
        position = position + 1
        empty_row = {col: "" for col in self._df.columns}
        self._df = pd.concat(
            [self._df.iloc[:position],
             pd.DataFrame([empty_row]),
             self._df.iloc[position:]]
        ).reset_index(drop=True)

        self.endInsertRows()
        return True


    def removeRow(self, position, parent=QModelIndex()):
        if position < 0 or position >= len(self._df):
            return False

        self.beginRemoveRows(QModelIndex(), position, position)

        self._df = self._df.drop(self._df.index[position]).reset_index(drop=True)

        self.endRemoveRows()
        return True

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("AXI4 Regs Editor")

        self.table = QTableView()

        # Buttons
        load_btn = QPushButton("Load CSV")
        save_btn = QPushButton("Save CSV")
        add_btn = QPushButton("Add Row")
        del_btn = QPushButton("Delete Row")
        gen_btn = QPushButton("Generate")

        load_btn.clicked.connect(self.load_csv)
        save_btn.clicked.connect(self.save_csv)
        add_btn.clicked.connect(self.add_row)
        del_btn.clicked.connect(self.delete_row)
        gen_btn.clicked.connect(self.generate)

        btn_layout = QHBoxLayout()
        btn_layout.addWidget(load_btn)
        btn_layout.addWidget(save_btn)
        btn_layout.addWidget(add_btn)
        btn_layout.addWidget(del_btn)
        btn_layout.addWidget(gen_btn)

        layout = QVBoxLayout()
        layout.addLayout(btn_layout)
        layout.addWidget(self.table)

        container = QWidget()
        container.setLayout(layout)
        self.setCentralWidget(container)

        self.model = None

    def load_csv(self):
        file_path, _ = QFileDialog.getOpenFileName(
            self, "Open CSV", "", "CSV Files (*.csv)"
        )

        if file_path:
            df = axi_rs.read_csv_to_df(file_path)

            self.model = PandasModel(df)
            self.table.setModel(self.model)

            # Choose which columns support multi-line editing
            multiline_cols = ["Description"]

            # Restricted-vocabulary columns: typed value must match one of
            # these (case-insensitive); accepted entries are snapped to the
            # canonical capitalization shown here.
            allowed_values = {
                "R/W/RW/etc.": ["R", "W", "RW", "RO", "WO", "COR", ""],
            }

            delegate = MultiLineDelegate(self.table, multiline_cols, allowed_values)
            self.table.setItemDelegate(delegate)

            # Enable wrapping + resizing
            self.table.setWordWrap(True)
            self.table.resizeColumnsToContents()
            self.table.resizeRowsToContents()
            self.table.horizontalHeader().setStretchLastSection(True)

    def save_csv(self):
        if not self.model:
            return

        file_path, _ = QFileDialog.getSaveFileName(
            self, "Save CSV", "", "CSV Files (*.csv)"
        )

        if file_path:
            # Clean the DataFrame of whitespace before saving
            self.model.beginResetModel()
            self.model._df = axi_rs.clean_df(self.model._df)
            self.model.endResetModel()

            axi_rs.write_df_to_csv(self.model._df, file_path)



    def add_row(self):
        if not self.model:
            return

        selected = self.table.selectionModel().selectedRows()

        if not selected:
            QMessageBox.warning(self, "No selection", "Select a row to add below.")
            return

        # add from bottom to top (safe for multiple selection)
        for index in sorted(selected, key=lambda x: x.row(), reverse=True):
            self.model.insertRow(index.row())


    def delete_row(self):
        if not self.model:
            return

        selected = self.table.selectionModel().selectedRows()

        if not selected:
            QMessageBox.warning(self, "No selection", "Select a row to delete.")
            return

        # delete from bottom to top (safe for multiple selection)
        for index in sorted(selected, key=lambda x: x.row(), reverse=True):
            self.model.removeRow(index.row())

    def generate(self):
        if not self.model:
            QMessageBox.warning(self, "No data", "Load a CSV before generating.")
            return

        df = self.model._df

        self.model.beginResetModel()
        self.model._df = axi_rs.clean_df(self.model._df)
        self.model._df = axi_rs.parse_regs(self.model._df)
        self.model.endResetModel()

        modules = [
            write_dot_h,
            write_sys_verilog,
            write_uvm_ral,
            write_vhdl,
        ]

        results = []
        for mod in modules:
            func = getattr(mod, "write_rows_to_file", None)
            if func is None:
                results.append(f"{mod.__name__}: no write_rows_to_file() found, skipped")
                continue
            try:
                func(self.model._df)
                results.append(f"{mod.__name__}: ok")
            except Exception as e:
                results.append(f"{mod.__name__}: error - {e}")

        QMessageBox.information(self, "Generate", "\n".join(results))

if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    app = QApplication(sys.argv)
    window = MainWindow()
    window.resize(900, 600)
    window.show()
    sys.exit(app.exec())
