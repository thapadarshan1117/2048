import 'package:equatable/equatable.dart';

/// Immutable value object describing a single numbered block.
///
/// This is the *only* source of truth for a block in the game. The Flame
/// [BlockComponent] is a pure visual projection of this object and never
/// owns gameplay data.
///
/// `id` is a stable identity used by the animation layer to follow a block
/// across drops, gravity shifts and merges. It is never reused.
class BlockState extends Equatable {
  const BlockState({
    required this.id,
    required this.value,
    required this.row,
    required this.column,
  });

  /// Stable unique identity of this block instance.
  final int id;

  /// The number displayed on the block (2, 4, 8, ...).
  final int value;

  /// Zero-based row index. `0` is the top row, `rows - 1` is the floor.
  final int row;

  /// Zero-based column index. `0` is the left-most column.
  final int column;

  /// A block with `value` is "doubled" when it merges.
  int get doubledValue => value * 2;

  BlockState copyWith({
    int? value,
    int? row,
    int? column,
  }) {
    return BlockState(
      id: id,
      value: value ?? this.value,
      row: row ?? this.row,
      column: column ?? this.column,
    );
  }

  /// Moves the block to a new cell without changing its identity or value.
  BlockState moveTo({required int row, required int column}) {
    return BlockState(id: id, value: value, row: row, column: column);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'value': value,
        'row': row,
        'column': column,
      };

  factory BlockState.fromJson(Map<String, dynamic> json) {
    return BlockState(
      id: (json['id'] as num).toInt(),
      value: (json['value'] as num).toInt(),
      row: (json['row'] as num).toInt(),
      column: (json['column'] as num).toInt(),
    );
  }

  @override
  List<Object?> get props => <Object?>[id, value, row, column];

  @override
  String toString() => 'BlockState(#$id v$value @${row}x$column)';
}
