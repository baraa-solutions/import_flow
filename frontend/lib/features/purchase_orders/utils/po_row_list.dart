import 'dart:collection';

/// The editable PO line / packing rows with a STABLE identity per row, for widget keys.
///
/// Rows are immutable models: every edit does `rows[i] = rows[i].copyWith(...)`, which yields
/// a new object. Keying the row widgets on the object (`identityHashCode(row)`) therefore
/// re-created the row's text fields on every keystroke (focus lost after one character);
/// keying on the index shows stale values after a remove / clone. Here an in-place
/// replacement (`[]=`) keeps the row's key, while added / inserted rows and whole-list
/// replacements (extraction, draft restore) get fresh keys.
class PoRowList<T extends Object> extends ListBase<T> {
  PoRowList([Iterable<T> rows = const []]) : _rows = List<T>.of(rows);

  final List<T> _rows;

  static final Expando<int> _keys = Expando<int>('poRowKey');
  static int _nextKey = 0;

  /// Stable key of [row] (assigned on first use).
  static int keyOf(Object row) => _keys[row] ??= ++_nextKey;

  @override
  int get length => _rows.length;

  @override
  set length(int newLength) => _rows.length = newLength;

  @override
  T operator [](int index) => _rows[index];

  /// In-place edit of a row: the new object inherits the replaced row's key.
  @override
  void operator []=(int index, T value) {
    final old = _rows[index];
    if (!identical(old, value) && _keys[value] == null) {
      _keys[value] = keyOf(old);
    }
    _rows[index] = value;
  }

  /// Replaces a row as a NEW row (new key): its fields are rebuilt from the new values.
  void replaceAsNew(int index, T value) => _rows[index] = value;

  // Structural changes delegate to the backing list so ListBase's setRange-based defaults
  // never move keys between rows.
  @override
  void add(T element) => _rows.add(element);

  @override
  void addAll(Iterable<T> iterable) => _rows.addAll(iterable);

  @override
  void insert(int index, T element) => _rows.insert(index, element);

  @override
  void insertAll(int index, Iterable<T> iterable) => _rows.insertAll(index, iterable);

  @override
  T removeAt(int index) => _rows.removeAt(index);

  @override
  bool remove(Object? element) => _rows.remove(element);

  @override
  T removeLast() => _rows.removeLast();

  @override
  void removeWhere(bool Function(T element) test) => _rows.removeWhere(test);

  @override
  void retainWhere(bool Function(T element) test) => _rows.retainWhere(test);

  @override
  void clear() => _rows.clear();
}
