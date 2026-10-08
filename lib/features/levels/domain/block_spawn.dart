/// A block that is already on the board when a level starts.
class BlockSpawn {
  const BlockSpawn({
    required this.value,
    required this.row,
    required this.column,
  });

  final int value;
  final int row;
  final int column;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'value': value,
        'row': row,
        'column': column,
      };

  factory BlockSpawn.fromJson(Map<String, dynamic> json) => BlockSpawn(
        value: (json['value'] as num).toInt(),
        row: (json['row'] as num).toInt(),
        column: (json['column'] as num).toInt(),
      );

  @override
  String toString() => 'BlockSpawn($value @${row}x$column)';
}
