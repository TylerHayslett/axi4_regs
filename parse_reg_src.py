
import sys
import pandas as pd
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QTableView,
    QFileDialog, QWidget, QVBoxLayout,
    QPushButton, QHBoxLayout, QMessageBox
)
from PyQt6.QtCore import Qt, QAbstractTableModel, QModelIndex


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
        self.setWindowTitle("Editable CSV Viewer")

        self.table = QTableView()

        # Buttons
        load_btn = QPushButton("Load CSV")
        save_btn = QPushButton("Save CSV")
        add_btn = QPushButton("Add Row")
        del_btn = QPushButton("Delete Row")

        load_btn.clicked.connect(self.load_csv)
        save_btn.clicked.connect(self.save_csv)
        add_btn.clicked.connect(self.add_row)
        del_btn.clicked.connect(self.delete_row)

        btn_layout = QHBoxLayout()
        btn_layout.addWidget(load_btn)
        btn_layout.addWidget(save_btn)
        btn_layout.addWidget(add_btn)
        btn_layout.addWidget(del_btn)

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
            df = pd.read_csv(file_path)
            df['Description'] = df['Description'].str.replace(r'\\n', '\n', regex=True)
            
            self.model = PandasModel(df)
            self.table.setModel(self.model)

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
            self.model._df.to_csv(file_path, index=False)


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

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.resize(900, 600)
    window.show()
    sys.exit(app.exec())
