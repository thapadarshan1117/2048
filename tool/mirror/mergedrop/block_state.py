"""Mirror of lib/features/game/domain/block_state.dart."""


class BlockState:
    __slots__ = ("id", "value", "row", "column")

    def __init__(self, id, value, row, column):
        self.id = id
        self.value = value
        self.row = row
        self.column = column

    @property
    def doubled_value(self):
        return self.value * 2

    def copy_with(self, value=None, row=None, column=None):
        return BlockState(
            self.id,
            self.value if value is None else value,
            self.row if row is None else row,
            self.column if column is None else column,
        )

    def move_to(self, row, column):
        return BlockState(self.id, self.value, row, column)

    def to_json(self):
        return {"id": self.id, "value": self.value, "row": self.row, "column": self.column}

    @staticmethod
    def from_json(data):
        return BlockState(data["id"], data["value"], data["row"], data["column"])

    def key(self):
        return (self.id, self.value, self.row, self.column)

    def __eq__(self, other):
        return isinstance(other, BlockState) and self.key() == other.key()

    def __hash__(self):
        return hash(self.key())

    def __repr__(self):
        return "BlockState(#%d v%d @%dx%d)" % (self.id, self.value, self.row, self.column)
